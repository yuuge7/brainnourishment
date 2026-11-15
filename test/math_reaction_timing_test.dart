import 'dart:math';

import 'package:brain_nourishment/src/application/warmup_controller.dart';
import 'package:brain_nourishment/src/domain/game.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void enterAnswer(WarmupController controller, int answer) {
  for (final digit in '$answer'.split('')) {
    controller.enterMathDigit(int.parse(digit));
  }
  controller.submitMath();
}

void main() {
  for (final difficulty in Difficulty.values) {
    test('calculate mode scores entered answers on ${difficulty.title}', () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: Exercise.logic,
          difficulty: difficulty,
          random: Random(80),
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        controller.setMathMode(MathMode.calculate);
        controller.enterMathDigit(2);
        expect(controller.mathInput, isEmpty);
        controller.beginRound();
        controller.setMathMode(MathMode.trueFalse);
        expect(controller.mathMode, MathMode.calculate);
        controller.answerMath(controller.math.isTrue);
        controller.submitMath();
        controller.enterMathDigit(-1);
        controller.enterMathDigit(10);
        expect(controller.score.attempts, 0);
        expect(controller.mathInput, isEmpty);
        controller.enterMathDigit(0);
        controller.enterMathDigit(5);
        expect(controller.mathInput, '5');
        controller.deleteMathDigit();
        expect(controller.mathInput, isEmpty);
        controller.pause();
        controller.enterMathDigit(5);
        expect(controller.mathInput, isEmpty);
        clock.elapse(const Duration(minutes: 1));
        controller.resume();
        enterAnswer(controller, controller.math.answer);
        controller.submitMath();
        expect(controller.score.correct, 1);
        expect(controller.score.attempts, 1);
        expect(controller.score.points, 10);
        clock.elapse(const Duration(milliseconds: 250));
        expect(controller.mathInput, isEmpty);
        enterAnswer(controller, controller.math.answer + 1);
        expect(controller.feedback, false);
        expect(controller.score.attempts, 2);
        expect(controller.score.points, 10);
      });
    });
  }

  test('the question with only 0.4 seconds left can become 13/13', () {
    fakeAsync((clock) {
      final controller = WarmupController(elapsed: () => clock.elapsed);
      addTearDown(controller.dispose);
      controller.beginRound();
      for (var i = 0; i < 11; i++) {
        controller.answerInk(controller.stroop.ink);
        clock.elapse(const Duration(milliseconds: 300));
      }
      clock.elapse(const Duration(milliseconds: 26050));
      controller.answerInk(controller.stroop.ink);
      clock.elapse(const Duration(milliseconds: 250));
      final lastPrompt = controller.stroop;
      expect(controller.score.correct, 12);
      clock.elapse(const Duration(milliseconds: 400));
      expect(controller.finishingQuestion, true);
      expect(controller.remaining, Duration.zero);
      clock.elapse(const Duration(seconds: 5));
      expect(controller.stroop, same(lastPrompt));
      controller.answerInk(lastPrompt.ink);
      controller.answerInk(lastPrompt.ink);
      clock.elapse(const Duration(milliseconds: 250));
      expect(controller.phase, WarmupPhase.ready);
      expect(controller.exercise, Exercise.logic);
      expect(controller.scores.first.correct, 13);
      expect(controller.scores.first.attempts, 13);
    });
  });

  for (final exercise in Exercise.values) {
    test('skipping the final ${exercise.title} does not record a miss', () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: exercise,
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        controller.beginRound();
        controller.skipFinalQuestion();
        expect(controller.phase, WarmupPhase.playing);
        clock.elapse(const Duration(seconds: 1));
        if (exercise == Exercise.memory) {
          controller.selectCell(controller.targets.first);
        }
        clock.elapse(const Duration(seconds: 29));
        expect(controller.finishingQuestion, true);
        controller.pause();
        controller.skipFinalQuestion();
        expect(controller.phase, WarmupPhase.playing);
        controller.resume();
        controller.skipFinalQuestion();
        controller.skipFinalQuestion();
        expect(controller.phase, WarmupPhase.finished);
        expect(controller.score.attempts, 0);
        expect(controller.score.points, 0);
      });
    });
  }

  test('a last memory preview finishes before recall after zero', () {
    fakeAsync((clock) {
      final controller = WarmupController(
        mode: TrainingMode.practice,
        practiceExercise: Exercise.memory,
        difficulty: Difficulty.standard,
        roundDuration: const Duration(seconds: 2),
        elapsed: () => clock.elapsed,
      );
      addTearDown(controller.dispose);
      controller.beginRound();
      clock.elapse(const Duration(seconds: 1));
      for (final cell in controller.targets) {
        controller.selectCell(cell);
      }
      clock.elapse(const Duration(milliseconds: 650));
      final lastTargets = controller.targets;
      clock.elapse(const Duration(milliseconds: 350));
      expect(controller.finishingQuestion, true);
      expect(controller.memoryPhase, MemoryPhase.showing);
      clock.elapse(const Duration(milliseconds: 650));
      expect(controller.memoryPhase, MemoryPhase.recalling);
      expect(controller.targets, lastTargets);
      for (final cell in lastTargets) {
        controller.selectCell(cell);
      }
      clock.elapse(const Duration(milliseconds: 650));
      expect(controller.phase, WarmupPhase.finished);
      expect(controller.score.correct, 2);
      expect(controller.score.attempts, 2);
      expect(controller.score.points, 60);
    });
  });

  test(
    'reaction waits, rejects early taps, and averages only valid samples',
    () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: Exercise.reaction,
          random: Random(5),
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        controller.beginRound();
        clock.elapse(const Duration(milliseconds: 1450));
        expect(controller.reactionPhase, ReactionPhase.waiting);
        controller.tapReaction();
        controller.tapReaction();
        expect(controller.reactionPhase, ReactionPhase.tooSoon);
        expect(controller.score.attempts, 1);
        expect(controller.score.reactionTimes, isEmpty);
        clock.elapse(const Duration(milliseconds: 900));
        for (final ms in [237, 183]) {
          clock.elapse(const Duration(seconds: 4));
          expect(controller.reactionPhase, ReactionPhase.ready);
          // Frame scheduling before presentation does not inflate the sample.
          clock.elapse(const Duration(milliseconds: 80));
          controller.reactionCuePresented(controller.reactionTrial);
          clock.elapse(Duration(milliseconds: ms));
          controller.reactionCuePresented(controller.reactionTrial);
          controller.tapReaction();
          controller.tapReaction();
          expect(controller.score.reactionTimes.last.inMilliseconds, ms);
          clock.elapse(const Duration(milliseconds: 900));
        }
        expect(controller.score.attempts, 3);
        expect(controller.score.correct, 2);
        expect(controller.score.points, 20);
        expect(controller.score.averageReaction!.inMilliseconds, 210);
        expect(controller.score.bestReaction!.inMilliseconds, 183);
        expect(
          () => controller.score.reactionTimes.add(Duration.zero),
          throwsUnsupportedError,
        );
      });
    },
  );

  test(
    'pausing a ready reaction cue restarts it and ignores old frame callbacks',
    () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: Exercise.reaction,
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        controller.beginRound();
        clock.elapse(const Duration(seconds: 4));
        final oldTrial = controller.reactionTrial;
        controller.reactionCuePresented(oldTrial);
        controller.pause();
        clock.elapse(const Duration(minutes: 2));
        controller.tapReaction();
        expect(controller.score.attempts, 0);
        controller.resume();
        expect(controller.reactionPhase, ReactionPhase.waiting);
        clock.elapse(const Duration(seconds: 4));
        controller.reactionCuePresented(oldTrial);
        controller.tapReaction();
        expect(controller.reactionPhase, ReactionPhase.tooSoon);
        expect(controller.score.reactionTimes, isEmpty);
        expect(controller.score.attempts, 1);
      });
    },
  );

  test('the last calculation and reaction can each finish after zero', () {
    for (final exercise in [Exercise.logic, Exercise.reaction]) {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: TrainingMode.practice,
          practiceExercise: exercise,
          mathMode: MathMode.calculate,
          roundDuration: const Duration(seconds: 1),
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        controller.beginRound();
        clock.elapse(const Duration(seconds: 1));
        expect(controller.finishingQuestion, true);
        if (exercise == Exercise.logic) {
          enterAnswer(controller, controller.math.answer);
        } else {
          clock.elapse(const Duration(seconds: 3));
          controller.reactionCuePresented(controller.reactionTrial);
          clock.elapse(const Duration(milliseconds: 200));
          controller.tapReaction();
        }
        clock.elapse(const Duration(seconds: 1));
        expect(controller.phase, WarmupPhase.finished);
        expect(controller.score.correct, 1);
        expect(controller.score.attempts, 1);
        expect(controller.score.points, 10);
      });
    }
  });
}
