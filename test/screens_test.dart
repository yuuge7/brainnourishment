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

void main() {
  setUpAll(() async {
    for (final font in ['SpaceGrotesk', 'Manrope']) {
      final loader = FontLoader(font)
        ..addFont(rootBundle.load('assets/fonts/$font.ttf'));
      await loader.load();
    }
  });
  for (final size in [
    const Size(568, 320),
    const Size(740, 360),
    const Size(1024, 600),
  ]) {
    testWidgets('all screens fit landscape ${size.width} x ${size.height}', (
      tester,
    ) async {
      setViewport(tester, size);
      await tester.pumpWidget(
        host(HomeScreen(stats: const ProgressStats(), onStart: () {})),
      );
      expect(tester.takeException(), isNull);
      var elapsed = Duration.zero;
      final controller = WarmupController(elapsed: () => elapsed);
      await tester.pumpWidget(
        host(WarmupScreen(controller: controller, onCompleted: (_) async {})),
      );
      expect(tester.takeException(), isNull);
      for (final exercise in Exercise.values) {
        controller.beginRound();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: exercise.title);
        elapsed += const Duration(seconds: 30);
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(ResultsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets(
    'full warmup scores answers, shows results, and retries a failed save',
    (tester) async {
      setViewport(tester, const Size(900, 420));
      var elapsed = Duration.zero;
      var saves = 0;
      final controller = WarmupController(
        random: Random(5),
        elapsed: () => elapsed,
      );
      await tester.pumpWidget(
        host(
          WarmupScreen(
            controller: controller,
            onCompleted: (scores) async {
              saves++;
              expect(scores.length, 3);
              if (saves == 1) throw StateError('Storage unavailable');
            },
          ),
        ),
      );
      await tester.tap(find.text('Begin focus'));
      await tester.pump();
      await tester.tap(
        find.byKey(ValueKey('ink-${controller.stroop.ink.name}')),
      );
      expect(controller.score.points, 10);
      elapsed += const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.text('Begin logic'));
      await tester.pump();
      await tester.tap(find.text(controller.math.isTrue ? 'True' : 'False'));
      expect(controller.score.points, 10);
      elapsed += const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.text('Begin memory'));
      await tester.pump();
      elapsed += const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
      for (final index in controller.targets) {
        await tester.tap(find.byKey(ValueKey('cell-$index')));
        await tester.pump();
      }
      expect(controller.score.points, 30);
      elapsed += const Duration(seconds: 29);
      await tester.pump(const Duration(seconds: 29));
      await tester.pump();
      expect(controller.totalPoints, 50);
      expect(saves, 1);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(saves, 2);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('home remains usable with enlarged text', (tester) async {
    setViewport(tester, const Size(740, 360));
    await tester.pumpWidget(
      host(
        HomeScreen(stats: const ProgressStats(), onStart: () {}),
        textScale: 1.5,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Start Daily Warmup'), findsOneWidget);
  });

  testWidgets('leaving an unfinished session does not save a completion', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 420));
    final repository = _MemoryRepository();
    await tester.pumpWidget(BrainNourishmentApp(repository: repository));
    await tester.pump();
    await tester.tap(find.text('Start Daily Warmup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('End warmup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End warmup'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });
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
