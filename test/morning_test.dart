import 'dart:convert';

import 'package:brain_nourishment/src/app.dart';
import 'package:brain_nourishment/src/application/warmup_controller.dart';
import 'package:brain_nourishment/src/data/progress_repository.dart';
import 'package:brain_nourishment/src/domain/game.dart';
import 'package:brain_nourishment/src/domain/morning.dart';
import 'package:brain_nourishment/src/domain/progress.dart';
import 'package:brain_nourishment/src/presentation/home_screen.dart';
import 'package:brain_nourishment/src/presentation/morning_setup_screen.dart';
import 'package:brain_nourishment/src/presentation/results_screen.dart';
import 'package:brain_nourishment/src/presentation/theme.dart';
import 'package:brain_nourishment/src/presentation/warmup_screen.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

MorningEntry entry(DateTime date, {String id = 'morning', int points = 30}) =>
    MorningEntry(
      id: id,
      day: ProgressStats.dayKey(date),
      points: points,
      before: EnergyLevel.sleepy,
    );

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    for (final font in ['SpaceGrotesk', 'Manrope']) {
      final loader = FontLoader(font)
        ..addFont(rootBundle.load('assets/fonts/$font.ttf'));
      await loader.load();
    }
  });

  for (final target in Difficulty.values) {
    test('morning builds gently toward ${target.title}', () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.morning,
          difficulty: target,
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        final expected = switch (target) {
          Difficulty.standard => [
            Difficulty.standard,
            Difficulty.standard,
            Difficulty.standard,
          ],
          Difficulty.challenge => [
            Difficulty.standard,
            Difficulty.standard,
            Difficulty.challenge,
          ],
          Difficulty.expert => [
            Difficulty.standard,
            Difficulty.challenge,
            Difficulty.expert,
          ],
        };
        expect(controller.exercises, [
          Exercise.memory,
          Exercise.focus,
          Exercise.logic,
        ]);
        for (var i = 0; i < 3; i++) {
          expect(controller.roundDifficulty, expected[i]);
          controller.beginRound();
          if (i == 0) {
            expect(controller.targets.length, 3);
            expect(controller.memoryFlash, const Duration(seconds: 1));
            expect(controller.gridSide, 3);
          }
          clock.elapse(const Duration(seconds: 30));
        }
        expect(controller.phase, WarmupPhase.finished);
      });
    });
  }

  test('each practice choice plays only that game', () {
    for (final exercise in Exercise.values) {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: exercise,
          elapsed: () => clock.elapsed,
        );
        expect(controller.exercises, [exercise]);
        controller.beginRound();
        clock.elapse(const Duration(seconds: 30));
        expect(controller.phase, WarmupPhase.finished);
        expect(controller.scores.single.exercise, exercise);
        controller.dispose();
      });
    }
  });

  test('legacy saved progress migrates without inventing morning history', () {
    final stats = ProgressStats.fromJson({
      'completed': 10,
      'streak': 3,
      'bestPoints': 250,
      'lastDay': '2026-11-13',
    });
    expect(stats.completed, 10);
    expect(stats.bestPoints, 250);
    expect(stats.streakOn(DateTime(2026, 11, 14)), 3);
    expect(stats.morningDays, 0);
    expect(stats.morningStreakOn(DateTime(2026, 11, 14)), 0);
    expect(stats.mornings, isEmpty);
    expect(
      ProgressStats.fromJson(jsonDecode(jsonEncode(stats.toJson()))).toJson(),
      stats.toJson(),
    );
  });

  test('morning streaks and week counts ignore replays and other modes', () {
    final firstDay = DateTime(2026, 11, 12, 23);
    var stats = const ProgressStats().complete(
      firstDay,
      30,
      morning: entry(firstDay),
    );
    final nextDay = DateTime(2026, 11, 13, 6);
    stats = stats.complete(nextDay, 20, morning: entry(nextDay, id: 'second'));
    stats = stats.complete(
      nextDay,
      40,
      morning: entry(nextDay, id: 'replay', points: 40),
    );
    expect(stats.completed, 3);
    expect(stats.morningDays, 2);
    expect(stats.morningStreak, 2);
    expect(stats.mornings.length, 2);
    expect(stats.morningOn(nextDay)!.id, 'replay');
    stats = stats.complete(DateTime(2026, 11, 14), 100);
    expect(stats.morningStreakOn(DateTime(2026, 11, 14)), 2);
    expect(stats.morningCompletedOn(DateTime(2026, 11, 14)), false);
    expect(stats.morningsThisWeek(DateTime(2026, 11, 14)), 2);
    expect(stats.morningStreakOn(DateTime(2026, 11, 15)), 0);
    final afterGap = DateTime(2026, 11, 16);
    stats = stats.complete(
      afterGap,
      0,
      morning: entry(afterGap, id: 'new-streak'),
    );
    expect(stats.morningStreak, 1);
    expect(stats.morningDays, 3);
  });

  test('history stays bounded while a long morning streak stays intact', () {
    var stats = const ProgressStats();
    for (var i = 0; i < 75; i++) {
      final date = DateTime(2026, 8, 1 + i);
      stats = stats.complete(
        date,
        i,
        morning: entry(date, id: '$i', points: i),
      );
    }
    expect(stats.mornings.length, 60);
    expect(stats.morningDays, 75);
    expect(stats.morningStreak, 75);
    expect(stats.morningsThisWeek(DateTime(2026, 8, 75)), 7);
    final restored = ProgressStats.fromJson(
      jsonDecode(jsonEncode(stats.toJson())),
    );
    expect(restored.toJson(), stats.toJson());
  });

  test(
    'reflections round trip Unicode and retries leave counters unchanged',
    () {
      final date = DateTime(2026, 11, 14);
      final initial = const ProgressStats().complete(
        date,
        40,
        morning: entry(date, points: 40),
      );
      final note = List.filled(100, '🌅').join();
      final reflection = MorningReflection(
        after: EnergyLevel.ready,
        intention: '  $note  ',
      );
      final updated = initial
          .reflect('morning', reflection)
          .reflect('morning', reflection);
      expect(initial.mornings.single.intention, isEmpty);
      expect(updated.completed, 1);
      expect(updated.morningDays, 1);
      expect(updated.morningStreak, 1);
      expect(updated.bestPoints, 40);
      final restored = ProgressStats.fromJson(
        jsonDecode(jsonEncode(updated.toJson())),
      );
      expect(restored.mornings.single.intention, note);
      expect(restored.mornings.single.before, EnergyLevel.sleepy);
      expect(restored.mornings.single.after, EnergyLevel.ready);
      expect(() => updated.reflect('missing', reflection), throwsStateError);
      expect(
        () => updated.reflect(
          'morning',
          MorningReflection(intention: '${note}x'),
        ),
        throwsArgumentError,
      );
      expect(() => updated.mornings.clear(), throwsUnsupportedError);
    },
  );

  test('malformed morning data is rejected', () {
    final date = DateTime(2026, 11, 14);
    final valid = const ProgressStats()
        .complete(date, 30, morning: entry(date))
        .toJson();
    for (final invalid in [
      {...valid, 'morningDays': -1},
      {...valid, 'morningStreak': '2'},
      {...valid, 'lastMorningDay': '2026-02-31'},
      {
        ...valid,
        'mornings': [null],
      },
      {...valid, 'mornings': 'no'},
      {
        ...valid,
        'mornings': [
          {...entry(date).toJson(), 'before': 'energetic'},
        ],
      },
      {
        ...valid,
        'mornings': [
          {...entry(date).toJson(), 'day': '2026-02-31'},
        ],
      },
      {
        ...valid,
        'mornings': [
          {...entry(date).toJson(), 'points': -1},
        ],
      },
    ]) {
      expect(() => ProgressStats.fromJson(invalid), throwsFormatException);
    }
    expect(
      () => const ProgressStats().complete(
        date,
        10,
        morning: entry(DateTime(2026, 11, 13)),
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    'morning completion and reflection retry save once and survive reload',
    (tester) async {
      viewport(tester, const Size(390, 844));
      var elapsed = Duration.zero;
      late WarmupController controller;
      final repository = _Repository(failOn: {1, 3});
      await tester.pumpWidget(
        BrainNourishmentApp(
          repository: repository,
          controllerFactory: (mode, difficulty, practice) =>
              controller = WarmupController(
                mode: mode,
                difficulty: difficulty,
                practiceExercise: practice,
                elapsed: () => elapsed,
              ),
        ),
      );
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('start-morning')));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('energy-before-sleepy')));
      await tap(
        tester,
        find.byKey(const ValueKey('morning-difficulty-expert')),
      );
      await tap(tester, find.byKey(const ValueKey('begin-morning')));
      await tester.pumpAndSettle();
      addTearDown(controller.dispose);
      expect(controller.difficulty, Difficulty.expert);
      expect(controller.roundDifficulty, Difficulty.standard);
      for (final exercise in controller.exercises) {
        await tap(tester, find.text('Begin ${exercise.skill.toLowerCase()}'));
        if (exercise == Exercise.memory) {
          elapsed += const Duration(seconds: 1);
          await tester.pump(const Duration(seconds: 1));
          for (final cell in controller.targets) {
            controller.selectCell(cell);
          }
          elapsed += const Duration(seconds: 29);
          await tester.pump(const Duration(seconds: 29));
        } else {
          if (exercise == Exercise.focus) {
            controller.answerInk(controller.stroop.ink);
          } else {
            controller.answerMath(controller.math.isTrue);
          }
          elapsed += const Duration(seconds: 30);
          await tester.pump(const Duration(seconds: 30));
        }
        await tester.pump();
      }
      expect(repository.calls, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('morning-intention')))
            .enabled,
        false,
      );
      await tap(tester, find.text('Retry'));
      expect(repository.saved.completed, 1);
      expect(repository.saved.morningDays, 1);
      expect(repository.saved.mornings.single.before, EnergyLevel.sleepy);
      await tap(tester, find.byKey(const ValueKey('energy-after-ready')));
      await tester.enterText(
        find.byKey(const ValueKey('morning-intention')),
        'Finish the sketch',
      );
      tester.testTextInput.hide();
      await tap(tester, find.byKey(const ValueKey('finish-session')));
      expect(
        find.text('Your check-in could not be saved. Try again.'),
        findsOneWidget,
      );
      expect(repository.saved.mornings.single.intention, isEmpty);
      await tap(tester, find.byKey(const ValueKey('finish-session')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repository.calls, 4);
      expect(repository.saved.completed, 1);
      expect(repository.saved.morningDays, 1);
      expect(repository.saved.mornings.single.after, EnergyLevel.ready);
      expect(repository.saved.mornings.single.points, 50);
      expect(find.text('Finish the sketch'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(BrainNourishmentApp(repository: repository));
      await tester.pump();
      expect(find.text('Finish the sketch'), findsOneWidget);
      expect(find.text('You showed up today.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('practice does not write a completion or morning streak', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    var elapsed = Duration.zero;
    late WarmupController controller;
    final repository = _Repository();
    await tester.pumpWidget(
      BrainNourishmentApp(
        repository: repository,
        controllerFactory: (mode, difficulty, practice) =>
            controller = WarmupController(
              mode: mode,
              difficulty: difficulty,
              practiceExercise: practice,
              elapsed: () => elapsed,
            ),
      ),
    );
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('practice-games')));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('practice-sequence')));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    expect(controller.exercise, Exercise.sequence);
    await tap(tester, find.text('Begin patterns'));
    controller.answerSequence(controller.sequence.answer);
    elapsed += const Duration(seconds: 30);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('PRACTICE COMPLETE'), findsOneWidget);
    expect(repository.calls, 0);
    expect(repository.saved.morningDays, 0);
    await tap(tester, find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup can be cancelled or used without a check-in', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final repository = _Repository();
    await tester.pumpWidget(BrainNourishmentApp(repository: repository));
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('start-morning')));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tap(tester, find.byKey(const ValueKey('start-morning')));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('begin-morning')));
    await tester.pumpAndSettle();
    final screen = tester.widget<WarmupScreen>(find.byType(WarmupScreen));
    expect(screen.morningBefore, isNull);
    expect(screen.difficulty, Difficulty.challenge);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('morning screens fit a small phone with enlarged text', (
    tester,
  ) async {
    viewport(tester, const Size(320, 568));
    Widget host(Widget child) => MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(1.5)),
        child: child!,
      ),
      home: child,
    );
    await tester.pumpWidget(host(const MorningSetupScreen()));
    await tester.ensureVisible(find.byKey(const ValueKey('begin-morning')));
    expect(tester.takeException(), isNull);
    var elapsed = Duration.zero;
    final controller = WarmupController(
      mode: TrainingMode.morning,
      difficulty: Difficulty.expert,
      elapsed: () => elapsed,
    );
    await tester.pumpWidget(
      host(WarmupScreen(controller: controller, onCompleted: (_) async {})),
    );
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull);
      controller.beginRound();
      await tester.pump();
      expect(tester.takeException(), isNull);
      elapsed += const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
    }
    expect(find.byType(ResultsScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('finish-session')));
    expect(
      find.byKey(const ValueKey('finish-session')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('an existing daily intention can be cleared explicitly', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    MorningReflection? saved;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: ResultsScreen(
          scores: const [],
          saving: false,
          saveFailed: false,
          onRetry: () {},
          onDone: () => done = true,
          mode: TrainingMode.morning,
          initialIntention: 'An old intention',
          onReflection: (reflection) async => saved = reflection,
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('morning-intention')), '');
    tester.testTextInput.hide();
    await tap(tester, find.byKey(const ValueKey('finish-session')));
    expect(saved!.intention, isEmpty);
    expect(done, true);
  });
}

class _Repository implements ProgressRepository {
  _Repository({this.failOn = const {}});
  final Set<int> failOn;
  var calls = 0;
  ProgressStats saved = const ProgressStats();
  @override
  Future<ProgressStats> load() async =>
      ProgressStats.fromJson(jsonDecode(jsonEncode(saved.toJson())));
  @override
  Future<void> save(ProgressStats stats) async {
    calls++;
    if (failOn.contains(calls)) throw StateError('Storage unavailable');
    saved = ProgressStats.fromJson(jsonDecode(jsonEncode(stats.toJson())));
  }
}
