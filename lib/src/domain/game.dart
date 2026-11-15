import 'dart:math';

enum Exercise {
  focus('Stroop effect', 'Focus', 'Read the ink. Ignore the word.'),
  logic('Quick math', 'Logic', 'Does the equation add up?'),
  memory('Memory grid', 'Memory', 'A brief look. Then trust your memory.'),
  sequence('Number sequence', 'Patterns', 'Find the rule. Fill the gap.'),
  switching('Rule switch', 'Flexibility', 'New number. Check the rule again.'),
  reaction('Reaction test', 'Reflexes', 'Wait for green. Then tap.');

  const Exercise(this.title, this.skill, this.subtitle);
  final String title;
  final String skill;
  final String subtitle;
}

enum TrainingMode {
  morning(
    'Morning wake-up',
    'Start gently with memory, then focus and math.',
    30,
  ),
  daily('Daily', 'The original three: focus, logic, and memory.', 30),
  circuit('Full circuit', 'All six games, including the reaction test.', 30),
  sprint('Sprint', 'All six games. Just 15 seconds per round.', 15),
  practice('Practice', 'One game, at your own chosen difficulty.', 30);

  const TrainingMode(this.title, this.description, this.roundSeconds);
  final String title;
  final String description;
  final int roundSeconds;

  List<Exercise> get exercises => switch (this) {
    morning => const [Exercise.memory, Exercise.focus, Exercise.logic],
    daily => const [Exercise.focus, Exercise.logic, Exercise.memory],
    circuit || sprint => Exercise.values,
    practice => const [Exercise.focus],
  };
  int get totalSeconds => exercises.length * roundSeconds;
}

enum Difficulty {
  standard(
    'Standard',
    'Steady math, 3 memory tiles, and fixed color buttons.',
    3,
    3,
    1000,
  ),
  challenge(
    'Challenge',
    'Multiplication, 4 memory tiles, and shuffled color buttons.',
    3,
    4,
    850,
  ),
  expert(
    'Expert',
    'Larger numbers, 5 tiles on a 4 × 4 grid, and a shorter flash.',
    4,
    5,
    650,
  );

  const Difficulty(
    this.title,
    this.description,
    this.gridSide,
    this.memoryTiles,
    this.flashMilliseconds,
  );
  final String title;
  final String description;
  final int gridSide;
  final int memoryTiles;
  final int flashMilliseconds;
  Duration get memoryFlash => Duration(milliseconds: flashMilliseconds);
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

enum MathOperation { addition, subtraction, multiplication }

enum MathMode {
  trueFalse('True or false'),
  calculate('Calculate it');

  const MathMode(this.title);
  final String title;
}

class MathPrompt {
  const MathPrompt(this.left, this.right, this.operation, this.proposed);

  factory MathPrompt.generate(
    Random random, {
    Difficulty difficulty = Difficulty.standard,
  }) {
    final operations = difficulty == Difficulty.standard
        ? MathOperation.values.take(2).toList()
        : MathOperation.values;
    final operation = operations[random.nextInt(operations.length)];
    final limit = switch (difficulty) {
      Difficulty.standard => 20,
      Difficulty.challenge => 35,
      Difficulty.expert => 99,
    };
    final multiplying = operation == MathOperation.multiplication;
    var left =
        random.nextInt(
          multiplying ? (difficulty == Difficulty.expert ? 19 : 12) : limit,
        ) +
        1;
    var right = random.nextInt(multiplying ? 12 : limit) + 1;
    if (operation == MathOperation.subtraction && left < right) {
      (left, right) = (right, left);
    }
    final answer = evaluate(left, right, operation);
    final offset = random.nextBool()
        ? 0
        : (random.nextBool() ? 1 : -1) * (random.nextInt(3) + 1);
    return MathPrompt(left, right, operation, answer + offset);
  }

  final int left;
  final int right;
  final MathOperation operation;
  final int proposed;

  static int evaluate(int left, int right, MathOperation operation) =>
      switch (operation) {
        MathOperation.addition => left + right,
        MathOperation.subtraction => left - right,
        MathOperation.multiplication => left * right,
      };
  int get answer => evaluate(left, right, operation);
  bool get isTrue => proposed == answer;
  String get expression {
    final symbol = switch (operation) {
      MathOperation.addition => '+',
      MathOperation.subtraction => '−',
      MathOperation.multiplication => '×',
    };
    return '$left $symbol $right';
  }

  String get equation => '$expression = $proposed';
}

enum SequenceRule { constantStep, growingStep, alternatingStep }

class SequencePrompt {
  SequencePrompt({
    required List<int> terms,
    required this.answer,
    required List<int> options,
    required this.rule,
  }) : terms = List.unmodifiable(terms),
       options = List.unmodifiable(options);

  factory SequencePrompt.generate(Random random, Difficulty difficulty) {
    final rule = SequenceRule.values[random.nextInt(difficulty.index + 1)];
    var value = random.nextInt(difficulty == Difficulty.expert ? 30 : 12) + 1;
    final step = random.nextInt(difficulty == Difficulty.expert ? 9 : 5) + 2;
    final otherStep = step + random.nextInt(4) + 1;
    final terms = [value];
    for (var i = 0; i < 4; i++) {
      value += switch (rule) {
        SequenceRule.constantStep => step,
        SequenceRule.growingStep => step + i,
        SequenceRule.alternatingStep => i.isEven ? step : otherStep,
      };
      terms.add(value);
    }
    final answer = terms.removeLast();
    final options = <int>{answer};
    while (options.length < 4) {
      options.add(answer + random.nextInt(19) - 9);
    }
    final shuffled = options.toList()..shuffle(random);
    return SequencePrompt(
      terms: terms,
      answer: answer,
      options: shuffled,
      rule: rule,
    );
  }

  final List<int> terms;
  final int answer;
  final List<int> options;
  final SequenceRule rule;
}

enum NumberRule { parity, magnitude }

class RulePrompt {
  const RulePrompt(this.number, this.rule, this.threshold);

  factory RulePrompt.generate(
    Random random,
    Difficulty difficulty, {
    NumberRule? previousRule,
  }) {
    final rule = previousRule == null
        ? NumberRule.values[random.nextInt(2)]
        : previousRule == NumberRule.parity
        ? NumberRule.magnitude
        : NumberRule.parity;
    final threshold = difficulty == Difficulty.expert ? 100 : 50;
    var number = random.nextInt(threshold * 2 - 1) + 1;
    if (number >= threshold) number++;
    return RulePrompt(number, rule, threshold);
  }

  final int number;
  final NumberRule rule;
  final int threshold;
  String get instruction =>
      rule == NumberRule.parity ? 'Even or odd?' : 'Below or above $threshold?';
  String get firstLabel => rule == NumberRule.parity ? 'Even' : 'Below';
  String get secondLabel => rule == NumberRule.parity ? 'Odd' : 'Above';
  bool get firstIsCorrect =>
      rule == NumberRule.parity ? number.isEven : number < threshold;
}

class GameScore {
  const GameScore({
    required this.exercise,
    this.correct = 0,
    this.attempts = 0,
    this.points = 0,
    this.reactionTimes = const [],
  });
  final Exercise exercise;
  final int correct;
  final int attempts;
  final int points;
  final List<Duration> reactionTimes;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  Duration? get bestReaction => reactionTimes.isEmpty
      ? null
      : reactionTimes.reduce((a, b) => a < b ? a : b);
  Duration? get averageReaction => reactionTimes.isEmpty
      ? null
      : Duration(
          microseconds:
              (reactionTimes.fold<int>(
                        0,
                        (sum, time) => sum + time.inMicroseconds,
                      ) /
                      reactionTimes.length)
                  .round(),
        );

  GameScore add({
    required bool success,
    required int earned,
    Duration? reactionTime,
  }) => GameScore(
    exercise: exercise,
    correct: correct + (success ? 1 : 0),
    attempts: attempts + 1,
    points: points + earned,
    reactionTimes: reactionTime == null
        ? reactionTimes
        : List.unmodifiable([...reactionTimes, reactionTime]),
  );
}
