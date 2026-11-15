import 'dart:math';

import 'package:brain_nourishment/src/app.dart';
import 'package:brain_nourishment/src/application/warmup_controller.dart';
import 'package:brain_nourishment/src/data/progress_repository.dart';
import 'package:brain_nourishment/src/domain/game.dart';
import 'package:brain_nourishment/src/domain/progress.dart';
import 'package:brain_nourishment/src/presentation/home_screen.dart';
import 'package:brain_nourishment/src/presentation/results_screen.dart';
import 'package:brain_nourishment/src/presentation/theme.dart';
import 'package:brain_nourishment/src/presentation/warmup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: child,
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
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

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(600, 960),
    const Size(740, 360),
  ]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets('six games fit $size at text scale $textScale', (
        tester,
      ) async {
        setViewport(tester, size);
        await tester.pumpWidget(
          host(
            HomeScreen(stats: const ProgressStats(), onStart: (_, _) {}),
            textScale: textScale,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('start-morning')));
        expect(
          find.byKey(const ValueKey('start-morning')).hitTestable(),
          findsOneWidget,
        );
        var elapsed = Duration.zero;
        final controller = WarmupController(
          mode: TrainingMode.circuit,
          difficulty: Difficulty.expert,
          elapsed: () => elapsed,
        );
        await tester.pumpWidget(
          host(
            WarmupScreen(controller: controller, onCompleted: (_) async {}),
            textScale: textScale,
          ),
        );
        for (final exercise in controller.exercises) {
          expect(
            tester.takeException(),
            isNull,
            reason: '${exercise.title} instructions',
          );
          if (exercise == Exercise.logic) {
            controller.setMathMode(MathMode.calculate);
          }
          controller.beginRound();
          await tester.pump();
          expect(tester.takeException(), isNull, reason: exercise.title);
          if (exercise == Exercise.memory) {
            expect(find.byKey(const ValueKey('cell-15')), findsOneWidget);
            elapsed += controller.memoryFlash;
            await tester.pump(controller.memoryFlash);
            expect(tester.takeException(), isNull);
          }
          elapsed += const Duration(seconds: 30);
          await tester.pump(const Duration(seconds: 30));
          controller.skipFinalQuestion();
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'After ${exercise.title}, ${controller.exercise.title}',
          );
        }
        expect(find.byType(ResultsScreen), findsOneWidget);
        await tester.ensureVisible(find.text('Done'));
        expect(find.text('Done').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
  }

  testWidgets('full circuit scores all six games and retries a failed save', (
    tester,
  ) async {
    setViewport(tester, const Size(390, 844));
    var elapsed = Duration.zero;
    var saves = 0;
    final controller = WarmupController(
      mode: TrainingMode.circuit,
      difficulty: Difficulty.standard,
      random: Random(5),
      elapsed: () => elapsed,
    );
    await tester.pumpWidget(
      host(
        WarmupScreen(
          controller: controller,
          onCompleted: (scores) async {
            saves++;
            expect(scores.length, 6);
            if (saves == 1) throw StateError('Storage unavailable');
          },
        ),
      ),
    );

    for (final exercise in controller.exercises) {
      await tapVisible(
        tester,
        find.text('Begin ${exercise.skill.toLowerCase()}'),
      );
      switch (exercise) {
        case Exercise.focus:
          await tapVisible(
            tester,
            find.byKey(ValueKey('ink-${controller.stroop.ink.name}')),
          );
        case Exercise.logic:
          await tapVisible(
            tester,
            find.text(controller.math.isTrue ? 'True' : 'False'),
          );
        case Exercise.memory:
          elapsed += controller.memoryFlash;
          await tester.pump(controller.memoryFlash);
          for (final index in controller.targets) {
            await tapVisible(tester, find.byKey(ValueKey('cell-$index')));
          }
        case Exercise.sequence:
          await tapVisible(
            tester,
            find.byKey(ValueKey('sequence-${controller.sequence.answer}')),
          );
        case Exercise.switching:
          await tapVisible(
            tester,
            find.byKey(
              ValueKey(
                controller.rulePrompt.firstIsCorrect
                    ? 'rule-first'
                    : 'rule-second',
              ),
            ),
          );
        case Exercise.reaction:
          elapsed += const Duration(seconds: 4);
          await tester.pump(const Duration(seconds: 4));
          elapsed += const Duration(milliseconds: 240);
          await tester.pump(const Duration(milliseconds: 240));
          await tester.tap(find.byKey(const ValueKey('reaction-target')));
          await tester.pump();
      }
      expect(controller.score.points, exercise == Exercise.memory ? 30 : 10);
      elapsed += const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 30));
      controller.skipFinalQuestion();
      await tester.pump();
    }
    expect(controller.totalPoints, 80);
    expect(saves, 1);
    await tapVisible(tester, find.text('Retry'));
    expect(saves, 2);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'session and difficulty selections reach the game; early exit does not save',
    (tester) async {
      setViewport(tester, const Size(390, 844));
      final repository = _MemoryRepository();
      await tester.pumpWidget(BrainNourishmentApp(repository: repository));
      await tester.pump();
      await tapVisible(tester, find.byKey(const ValueKey('other-modes')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('mode-sprint')));
      await tapVisible(tester, find.byKey(const ValueKey('difficulty-expert')));
      await tapVisible(tester, find.text('Start Sprint'));
      await tester.pumpAndSettle();
      final screen = tester.widget<WarmupScreen>(find.byType(WarmupScreen));
      expect(screen.mode, TrainingMode.sprint);
      expect(screen.difficulty, Difficulty.expert);
      expect(find.text('15 seconds'), findsOneWidget);
      expect(find.text('Round 1 of 6'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('End warmup'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('End warmup'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repository.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pause overlay blocks play until resumed', (tester) async {
    setViewport(tester, const Size(390, 844));
    final controller = WarmupController();
    await tester.pumpWidget(
      host(WarmupScreen(controller: controller, onCompleted: (_) async {})),
    );
    await tapVisible(tester, find.text('Begin focus'));
    await tapVisible(tester, find.byTooltip('Pause warmup'));
    expect(controller.paused, true);
    expect(find.text('Your timer is paused.'), findsOneWidget);
    await tapVisible(tester, find.text('Resume warmup'));
    expect(controller.paused, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'calculate selector and keypad finish the last answer after zero',
    (tester) async {
      setViewport(tester, const Size(390, 844));
      var elapsed = Duration.zero;
      var completions = 0;
      final controller = WarmupController(
        mode: TrainingMode.practice,
        practiceExercise: Exercise.logic,
        roundDuration: const Duration(seconds: 1),
        elapsed: () => elapsed,
      );
      await tester.pumpWidget(
        host(
          WarmupScreen(
            controller: controller,
            onCompleted: (_) async => completions++,
          ),
        ),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('math-mode-calculate')),
      );
      await tapVisible(tester, find.text('Begin logic'));
      expect(find.text('True'), findsNothing);
      expect(find.text(controller.math.equation), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-submit')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.byKey(const ValueKey('math-digit-9')));
      await tapVisible(tester, find.byKey(const ValueKey('math-delete')));
      expect(controller.mathInput, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
      expect(controller.mathInput, '9');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(controller.mathInput, isEmpty);
      final keypadPosition = tester.getRect(
        find.byKey(const ValueKey('math-digit-1')),
      );
      elapsed = const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time’s up. Finish this question.'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('math-digit-1'))),
        keypadPosition,
      );
      for (final digit in '${controller.math.answer}'.split('')) {
        await tapVisible(tester, find.byKey(ValueKey('math-digit-$digit')));
      }
      await tapVisible(tester, find.byKey(const ValueKey('math-submit')));
      elapsed += const Duration(milliseconds: 250);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.text('1/1 correct · 100%'), findsOneWidget);
      expect(completions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'reaction target changes color, reports early taps, and records key presses',
    (tester) async {
      setViewport(tester, const Size(390, 844));
      var elapsed = Duration.zero;
      final controller = WarmupController(
        mode: TrainingMode.practice,
        practiceExercise: Exercise.reaction,
        elapsed: () => elapsed,
      );
      await tester.pumpWidget(
        host(WarmupScreen(controller: controller, onCompleted: (_) async {})),
      );
      await tapVisible(tester, find.text('Begin reflexes'));
      expect(find.text('Wait for green'), findsOneWidget);
      final red = tester
          .widget<Container>(find.byKey(const ValueKey('reaction-target')))
          .decoration;
      await tester.tap(find.byKey(const ValueKey('reaction-target')));
      await tester.pump();
      expect(find.text('Too soon'), findsOneWidget);
      expect(controller.score.reactionTimes, isEmpty);
      elapsed += const Duration(milliseconds: 900);
      await tester.pump(const Duration(milliseconds: 900));
      elapsed += const Duration(seconds: 4);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Tap now!'), findsOneWidget);
      final green = tester
          .widget<Container>(find.byKey(const ValueKey('reaction-target')))
          .decoration;
      expect(red, isNot(green));
      elapsed += const Duration(milliseconds: 225);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('225 ms'), findsOneWidget);
      expect(controller.score.reactionTimes.single.inMilliseconds, 225);
      elapsed = const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(
        find.text('225 ms average · 225 ms best\n1 reaction · 1 false start'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

class _MemoryRepository implements ProgressRepository {
  var saves = 0;
  @override
  Future<ProgressStats> load() async => const ProgressStats();
  @override
  Future<void> save(ProgressStats stats) async {
    saves++;
  }
}
