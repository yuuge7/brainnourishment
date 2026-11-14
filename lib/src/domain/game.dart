import 'dart:math';

enum Exercise {
  focus('Stroop effect', 'Focus', 'Read the ink. Ignore the word.'),
  logic('Quick math', 'Logic', 'Does the equation add up?'),
  memory('Memory grid', 'Memory', 'A brief look. Then trust your memory.');

  const Exercise(this.title, this.skill, this.subtitle);
  final String title;
  final String skill;
  final String subtitle;
}

enum Ink { red, blue, green, yellow }

class StroopPrompt {
  const StroopPrompt(this.word, this.ink);

  factory StroopPrompt.generate(Random random) {
    final ink = Ink.values[random.nextInt(Ink.values.length)];
    final others = Ink.values.where((value) => value != ink).toList();
    return StroopPrompt(others[random.nextInt(others.length)], ink);
  }

  final Ink word;
  final Ink ink;
}

class MathPrompt {
  const MathPrompt(this.left, this.right, this.isAddition, this.proposed);

  factory MathPrompt.generate(Random random) {
    final isAddition = random.nextBool();
    var left = random.nextInt(20) + 1;
    var right = random.nextInt(20) + 1;
    if (!isAddition && left < right) {
      (left, right) = (right, left);
    }
    final answer = isAddition ? left + right : left - right;
    final offset = random.nextBool()
        ? 0
        : (random.nextBool() ? 1 : -1) * (random.nextInt(3) + 1);
    return MathPrompt(left, right, isAddition, answer + offset);
  }

  final int left;
  final int right;
  final bool isAddition;
  final int proposed;

  bool get isTrue => proposed == (isAddition ? left + right : left - right);
  String get equation => '$left ${isAddition ? '+' : '−'} $right = $proposed';
}

class GameScore {
  const GameScore({
    required this.exercise,
    this.correct = 0,
    this.attempts = 0,
    this.points = 0,
  });

  final Exercise exercise;
  final int correct;
  final int attempts;
  final int points;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  GameScore add({required bool success, required int earned}) => GameScore(
    exercise: exercise,
    correct: correct + (success ? 1 : 0),
    attempts: attempts + 1,
    points: points + earned,
  );
}
