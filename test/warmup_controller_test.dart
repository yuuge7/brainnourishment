import 'dart:math';

import 'package:brain_nourishment/src/application/warmup_controller.dart';
import 'package:brain_nourishment/src/domain/game.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stroop always conflicts, scores ink, and ignores duplicate taps', () {
    fakeAsync((clock) {
      final controller = WarmupController(
        random: Random(7),
        elapsed: () => clock.elapsed,
      );
      addTearDown(controller.dispose);
      controller.beginRound();
      for (var i = 0; i < 50; i++) {
        expect(controller.stroop.word, isNot(controller.stroop.ink));
        controller.answerInk(controller.stroop.ink);
        controller.answerInk(controller.stroop.ink);
        expect(controller.score.attempts, i + 1);
        clock.elapse(const Duration(milliseconds: 300));
      }
      expect(controller.score.points, 500);
      controller.answerInk(controller.stroop.word);
      expect(controller.score.correct, 50);
      expect(controller.score.attempts, 51);
      expect(controller.feedback, false);
    });
  });

  test('each round lasts 30 active seconds and ends in the required order', () {
    fakeAsync((clock) {
      final controller = WarmupController(elapsed: () => clock.elapsed);
      addTearDown(controller.dispose);
      for (final exercise in controller.exercises) {
        expect(controller.exercise, exercise);
        expect(controller.phase, WarmupPhase.ready);
        controller.beginRound();
        clock.elapse(const Duration(milliseconds: 29950));
        expect(controller.phase, WarmupPhase.playing);
        expect(controller.secondsLeft, 1);
        clock.elapse(const Duration(milliseconds: 50));
        expect(
          controller.phase,
          exercise == Exercise.memory
              ? WarmupPhase.finished
              : WarmupPhase.ready,
        );
      }
      expect(controller.scores.length, 3);
      expect(controller.remaining, Duration.zero);
      controller.answerMath(true);
      controller.selectCell(0);
      expect(controller.totalPoints, 0);
    });
  });

  test(
    'pause blocks input and preserves remaining time across backgrounding',
    () {
      fakeAsync((clock) {
        final controller = WarmupController(elapsed: () => clock.elapsed);
        addTearDown(controller.dispose);
        controller.beginRound();
        clock.elapse(const Duration(seconds: 4));
        controller.pause();
        clock.elapse(const Duration(minutes: 2));
        controller.answerInk(controller.stroop.ink);
        expect(controller.score.points, 0);
        expect(controller.secondsLeft, 26);
        controller.resume();
        clock.elapse(const Duration(seconds: 25));
        expect(controller.phase, WarmupPhase.playing);
        clock.elapse(const Duration(seconds: 1));
        expect(controller.exercise, Exercise.logic);
      });
    },
  );

  test('math evaluates both true and false equations and scores choices', () {
    final random = Random(9);
    var seenTrue = false;
    var seenFalse = false;
    for (var i = 0; i < 200; i++) {
      final prompt = MathPrompt.generate(random);
      final actual = switch (prompt.operation) {
        MathOperation.addition => prompt.left + prompt.right,
        MathOperation.subtraction => prompt.left - prompt.right,
        MathOperation.multiplication => prompt.left * prompt.right,
      };
      expect(prompt.isTrue, prompt.proposed == actual);
      expect(actual, greaterThanOrEqualTo(0));
      seenTrue |= prompt.isTrue;
      seenFalse |= !prompt.isTrue;
    }
    expect(seenTrue && seenFalse, true);
    fakeAsync((clock) {
      final controller = WarmupController(elapsed: () => clock.elapsed);
      addTearDown(controller.dispose);
      controller.beginRound();
      clock.elapse(const Duration(seconds: 30));
      controller.beginRound();
      controller.answerMath(controller.math.isTrue);
      expect(controller.score.points, 10);
      clock.elapse(const Duration(milliseconds: 300));
      controller.answerMath(!controller.math.isTrue);
      expect(controller.score.attempts, 2);
      expect(controller.score.correct, 1);
    });
  });

  test('memory flashes for one second, rejects duplicates, and gives partial credit', () {
    fakeAsync((clock) {
      final controller = WarmupController(
        random: Random(42),
        difficulty: Difficulty.standard,
        elapsed: () => clock.elapsed,
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 2; i++) {
        controller.beginRound();
        clock.elapse(const Duration(seconds: 30));
      }
      controller.beginRound();
      final targets = controller.targets.toList();
      expect(targets.length, 3);
      controller.selectCell(targets.first);
      expect(controller.selected, isEmpty);
      clock.elapse(const Duration(milliseconds: 950));
      expect(controller.memoryPhase, MemoryPhase.showing);
      clock.elapse(const Duration(milliseconds: 50));
      expect(controller.memoryPhase, MemoryPhase.recalling);
      controller.selectCell(targets.first);
      controller.selectCell(targets.first);
      expect(controller.selected.length, 1);
      controller.selectCell(targets[1]);
      controller.selectCell(targets[2]);
      expect(controller.score.points, 30);
      expect(controller.score.correct, 1);
      expect(controller.memoryPhase, MemoryPhase.feedback);
      clock.elapse(const Duration(milliseconds: 650));
      expect(controller.memoryPhase, MemoryPhase.showing);
      expect(controller.selected, isEmpty);
      clock.elapse(const Duration(seconds: 1));
      final newTargets = controller.targets.toList();
      final wrong = List.generate(
        9,
        (i) => i,
      ).firstWhere((i) => !controller.targets.contains(i));
      controller.selectCell(newTargets[0]);
      controller.selectCell(newTargets[1]);
      controller.selectCell(wrong);
      expect(controller.score.points, 50);
      expect(controller.score.correct, 1);
      expect(controller.score.attempts, 2);
    });
  });

  test(
    'memory pause restarts an interrupted flash; incomplete recall counts once',
    () {
      fakeAsync((clock) {
        final controller = WarmupController(
          difficulty: Difficulty.standard,
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        for (var i = 0; i < 2; i++) {
          controller.beginRound();
          clock.elapse(const Duration(seconds: 30));
        }
        controller.beginRound();
        clock.elapse(const Duration(milliseconds: 500));
        controller.pause();
        clock.elapse(const Duration(minutes: 1));
        controller.resume();
        clock.elapse(const Duration(milliseconds: 950));
        expect(controller.memoryPhase, MemoryPhase.showing);
        clock.elapse(const Duration(milliseconds: 50));
        expect(controller.memoryPhase, MemoryPhase.recalling);
        controller.selectCell(controller.targets.first);
        clock.elapse(const Duration(seconds: 29));
        expect(controller.phase, WarmupPhase.finished);
        expect(controller.score.attempts, 1);
        expect(controller.score.points, 0);
      });
    },
  );

  test(
    'late answer cannot score after the deadline; dispose cancels timers',
    () {
      fakeAsync((clock) {
        var time = Duration.zero;
        final controller = WarmupController(elapsed: () => time);
        controller.beginRound();
        time = const Duration(seconds: 31);
        controller.answerInk(controller.stroop.ink);
        expect(controller.exercise, Exercise.logic);
        expect(controller.scores.first.points, 0);
        controller.beginRound();
        controller.dispose();
        expect(clock.periodicTimerCount, 0);
      });
    },
  );
}
