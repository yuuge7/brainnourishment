import 'dart:math';

import 'package:brain_nourishment/src/application/warmup_controller.dart';
import 'package:brain_nourishment/src/domain/game.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in TrainingMode.values) {
    test('${mode.title} uses its full game order and active duration', () {
      fakeAsync((clock) {
        final controller = WarmupController(
          mode: mode,
          elapsed: () => clock.elapsed,
        );
        addTearDown(controller.dispose);
        expect(controller.difficulty, Difficulty.challenge);
        expect(
          controller.roundDuration.inSeconds * controller.exercises.length,
          mode.totalSeconds,
        );
        for (var i = 0; i < mode.exercises.length; i++) {
          expect(controller.exercise, mode.exercises[i]);
          expect(controller.roundIndex, i);
          clock.elapse(const Duration(minutes: 1));
          expect(controller.phase, WarmupPhase.ready);
          controller.beginRound();
          clock.elapse(
            controller.roundDuration - const Duration(milliseconds: 50),
          );
          expect(controller.phase, WarmupPhase.playing);
          clock.elapse(const Duration(milliseconds: 50));
        }
        expect(controller.phase, WarmupPhase.finished);
        expect(
          controller.scores.map((score) => score.exercise),
          mode.exercises,
        );
        controller.beginRound();
        expect(controller.phase, WarmupPhase.finished);
      });
    });
  }

  for (final difficulty in Difficulty.values) {
    test(
      '${difficulty.title} memory uses the right grid, flash, and scoring',
      () {
        fakeAsync((clock) {
          final controller = WarmupController(
            difficulty: difficulty,
            elapsed: () => clock.elapsed,
          );
          addTearDown(controller.dispose);
          for (var i = 0; i < 2; i++) {
            controller.beginRound();
            clock.elapse(controller.roundDuration);
          }
          controller.beginRound();
          expect(controller.targets.length, difficulty.memoryTiles);
          expect(
            controller.targets.every(
              (i) => i >= 0 && i < difficulty.gridSide * difficulty.gridSide,
            ),
            true,
          );
          controller.selectCell(controller.targets.first);
          expect(controller.selected, isEmpty);
          clock.elapse(
            difficulty.memoryFlash - const Duration(milliseconds: 50),
          );
          expect(controller.memoryPhase, MemoryPhase.showing);
          clock.elapse(const Duration(milliseconds: 50));
          expect(controller.memoryPhase, MemoryPhase.recalling);
          controller.selectCell(-1);
          controller.selectCell(difficulty.gridSide * difficulty.gridSide);
          expect(controller.selected, isEmpty);
          for (final cell in controller.targets) {
            controller.selectCell(cell);
          }
          expect(controller.score.points, difficulty.memoryTiles * 10);
          expect(controller.score.correct, 1);
          controller.selectCell(0);
          expect(controller.score.attempts, 1);
        });
      },
    );

    test(
      '${difficulty.title} generated math, sequences, and rules are valid',
      () {
        final random = Random(120 + difficulty.index);
        final operations = <MathOperation>{};
        final sequenceRules = <SequenceRule>{};
        NumberRule? previousRule;
        for (var i = 0; i < 300; i++) {
          final math = MathPrompt.generate(random, difficulty: difficulty);
          operations.add(math.operation);
          final actual = switch (math.operation) {
            MathOperation.addition => math.left + math.right,
            MathOperation.subtraction => math.left - math.right,
            MathOperation.multiplication => math.left * math.right,
          };
          expect(math.isTrue, math.proposed == actual);
          final sequence = SequencePrompt.generate(random, difficulty);
          sequenceRules.add(sequence.rule);
          expect(sequence.options.toSet().length, 4);
          expect(
            sequence.options
                .where((option) => option == sequence.answer)
                .length,
            1,
          );
          final differences = [
            for (var j = 1; j < 4; j++)
              sequence.terms[j] - sequence.terms[j - 1],
          ];
          final nextStep = switch (sequence.rule) {
            SequenceRule.constantStep => differences.last,
            SequenceRule.growingStep => differences.last + 1,
            SequenceRule.alternatingStep => differences[1],
          };
          expect(sequence.answer, sequence.terms.last + nextStep);
          final rule = RulePrompt.generate(
            random,
            difficulty,
            previousRule: previousRule,
          );
          expect(rule.number, isNot(rule.threshold));
          if (previousRule != null) expect(rule.rule, isNot(previousRule));
          expect(
            rule.firstIsCorrect,
            rule.rule == NumberRule.parity
                ? rule.number % 2 == 0
                : rule.number < rule.threshold,
          );
          previousRule = rule.rule;
        }
        expect(operations.length, difficulty == Difficulty.standard ? 2 : 3);
        expect(sequenceRules.length, difficulty.index + 1);
      },
    );
  }

  test(
    'new games enforce input guards, pause, feedback delay, and deadline',
    () {
      fakeAsync((clock) {
        var time = Duration.zero;
        final controller = WarmupController(
          mode: TrainingMode.circuit,
          random: Random(6),
          elapsed: () => time,
        );
        addTearDown(controller.dispose);
        for (var i = 0; i < 3; i++) {
          controller.beginRound();
          time += controller.roundDuration;
          clock.elapse(controller.roundDuration);
        }
        controller.answerSequence(0);
        expect(controller.score.attempts, 0);
        controller.beginRound();
        controller.answerSequence(-1000);
        expect(controller.score.attempts, 0);
        controller.pause();
        controller.answerSequence(controller.sequence.answer);
        expect(controller.score.points, 0);
        time += const Duration(minutes: 2);
        clock.elapse(const Duration(minutes: 2));
        controller.resume();
        controller.answerSequence(controller.sequence.answer);
        controller.answerSequence(controller.sequence.answer);
        expect(controller.score.points, 10);
        expect(controller.score.attempts, 1);
        time += const Duration(milliseconds: 250);
        clock.elapse(const Duration(milliseconds: 250));
        controller.answerSequence(
          controller.sequence.options.firstWhere(
            (option) => option != controller.sequence.answer,
          ),
        );
        expect(controller.score.correct, 1);
        expect(controller.score.attempts, 2);
        time += controller.roundDuration;
        clock.elapse(controller.roundDuration);
        expect(controller.exercise, Exercise.switching);
        controller.beginRound();
        final firstRule = controller.rulePrompt.rule;
        controller.answerRule(controller.rulePrompt.firstIsCorrect);
        expect(controller.score.points, 10);
        time += const Duration(milliseconds: 250);
        clock.elapse(const Duration(milliseconds: 250));
        expect(controller.rulePrompt.rule, isNot(firstRule));
        controller.answerRule(!controller.rulePrompt.firstIsCorrect);
        expect(controller.score.correct, 1);
        expect(controller.score.attempts, 2);
        time += const Duration(milliseconds: 250);
        clock.elapse(const Duration(milliseconds: 250));
        time += controller.roundDuration;
        controller.answerRule(controller.rulePrompt.firstIsCorrect);
        expect(controller.phase, WarmupPhase.finished);
        expect(controller.score.points, 10);
        expect(controller.totalPoints, 20);
      });
    },
  );
}
