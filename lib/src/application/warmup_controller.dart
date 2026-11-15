import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/game.dart';

enum WarmupPhase { ready, playing, finished }

enum MemoryPhase { showing, recalling, feedback }

enum ReactionPhase { waiting, ready, result, tooSoon }

/// Owns timing, question generation, scoring, and exercise transitions.
/// Widgets only render state and forward actions. No navigation or storage here.
class WarmupController extends ChangeNotifier {
  WarmupController({
    Random? random,
    this.mode = TrainingMode.daily,
    this.difficulty = Difficulty.challenge,
    this.practiceExercise = Exercise.focus,
    MathMode mathMode = MathMode.trueFalse,
    Duration? roundDuration,
    Duration Function()? elapsed,
  }) : assert(roundDuration == null || roundDuration > Duration.zero),
       roundDuration = roundDuration ?? Duration(seconds: mode.roundSeconds),
       _random = random ?? Random(),
       // Keep the public option separate from mutable round state.
       // ignore: prefer_initializing_formals
       _mathMode = mathMode,
       _elapsedOverride = elapsed;

  final TrainingMode mode;
  final Difficulty difficulty;
  final Exercise practiceExercise;

  /// Morning rounds ramp from Standard to the selected finishing level.
  Difficulty get roundDifficulty => mode == TrainingMode.morning
      ? Difficulty.values[(difficulty.index - (exercises.length - 1 - _index))
            .clamp(0, difficulty.index)]
      : difficulty;
  final Duration roundDuration;
  final Random _random;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _disposed = false;
  late final List<GameScore> _scores = [
    for (final exercise in exercises) GameScore(exercise: exercise),
  ];

  WarmupPhase _phase = WarmupPhase.ready;
  WarmupPhase get phase => _phase;
  int _index = 0;
  List<Exercise> get exercises =>
      mode == TrainingMode.practice ? [practiceExercise] : mode.exercises;
  int get roundIndex => _index;
  Exercise get exercise => exercises[_index];
  List<GameScore> get scores => List.unmodifiable(_scores);
  GameScore get score => _scores[_index];
  int get totalPoints => _scores.fold(0, (sum, item) => sum + item.points);

  Duration _remaining = Duration.zero;
  Duration get remaining =>
      _phase == WarmupPhase.ready ? roundDuration : _remaining;
  int get secondsLeft => (remaining.inMilliseconds / 1000).ceil();
  double get fractionLeft =>
      (remaining.inMicroseconds / roundDuration.inMicroseconds).clamp(0, 1);
  Duration get _elapsed => _elapsedOverride?.call() ?? _stopwatch.elapsed;
  Duration _roundStartedAt = Duration.zero;
  bool _timeUp = false;
  bool get finishingQuestion =>
      _phase == WarmupPhase.playing && _timeUp && _feedback == null;

  bool _paused = false;
  Duration _pausedAt = Duration.zero;
  bool get paused => _paused;
  bool? _feedback;
  bool? get feedback => _feedback;
  Duration? _nextPromptAt;
  StroopPrompt _stroop = const StroopPrompt(Ink.red, Ink.blue);
  StroopPrompt get stroop => _stroop;
  List<Ink> _inkChoices = Ink.values;
  List<Ink> get inkChoices => List.unmodifiable(_inkChoices);
  MathPrompt _math = const MathPrompt(14, 8, MathOperation.subtraction, 5);
  MathPrompt get math => _math;
  MathMode _mathMode;
  MathMode get mathMode => _mathMode;
  String _mathInput = '';
  String get mathInput => _mathInput;
  late SequencePrompt _sequence;
  SequencePrompt get sequence => _sequence;
  RulePrompt? _rulePrompt;
  RulePrompt get rulePrompt => _rulePrompt!;
  int get gridSide => roundDifficulty.gridSide;
  int get memoryTileCount => roundDifficulty.memoryTiles;
  Duration get memoryFlash => roundDifficulty.memoryFlash;
  MemoryPhase _memoryPhase = MemoryPhase.showing;
  MemoryPhase get memoryPhase => _memoryPhase;
  Set<int> _targets = {};
  Set<int> get targets => Set.unmodifiable(_targets);
  final Set<int> _selected = {};
  Set<int> get selected => Set.unmodifiable(_selected);
  Duration _memoryDeadline = Duration.zero;
  ReactionPhase _reactionPhase = ReactionPhase.waiting;
  ReactionPhase get reactionPhase => _reactionPhase;
  Duration _reactionDeadline = Duration.zero;
  Duration? _reactionShownAt;
  int _reactionTrial = 0;
  int get reactionTrial => _reactionTrial;

  bool get canAnswer =>
      !_disposed &&
      _phase == WarmupPhase.playing &&
      !_paused &&
      _feedback == null;

  void beginRound() {
    if (_phase != WarmupPhase.ready) return;
    _phase = WarmupPhase.playing;
    _paused = false;
    _stopwatch.start();
    _roundStartedAt = _elapsed;
    _remaining = roundDuration;
    _timeUp = false;
    _feedback = null;
    _nextPromptAt = null;
    _generatePrompt();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    notifyListeners();
  }

  void _generatePrompt() {
    switch (exercise) {
      case Exercise.focus:
        _stroop = StroopPrompt.generate(_random);
        _inkChoices = Ink.values.toList();
        if (roundDifficulty != Difficulty.standard) {
          _inkChoices.shuffle(_random);
        }
      case Exercise.logic:
        _math = MathPrompt.generate(_random, difficulty: roundDifficulty);
        _mathInput = '';
      case Exercise.memory:
        final cells = List.generate(gridSide * gridSide, (index) => index)
          ..shuffle(_random);
        _targets = cells.take(memoryTileCount).toSet();
        _selected.clear();
        _memoryPhase = MemoryPhase.showing;
        _memoryDeadline = _elapsed + memoryFlash;
      case Exercise.sequence:
        _sequence = SequencePrompt.generate(_random, roundDifficulty);
      case Exercise.switching:
        _rulePrompt = RulePrompt.generate(
          _random,
          roundDifficulty,
          previousRule: _rulePrompt?.rule,
        );
      case Exercise.reaction:
        _reactionTrial++;
        _reactionPhase = ReactionPhase.waiting;
        _reactionShownAt = null;
        _reactionDeadline =
            _elapsed + Duration(milliseconds: 1500 + _random.nextInt(2501));
    }
  }

  void setMathMode(MathMode mode) {
    if (_phase != WarmupPhase.ready || exercise != Exercise.logic) return;
    _mathMode = mode;
    notifyListeners();
  }

  void answerInk(Ink ink) {
    if (exercise != Exercise.focus || !canAnswer) return;
    _answer(ink == _stroop.ink);
  }

  void answerMath(bool answer) {
    if (exercise != Exercise.logic ||
        _mathMode != MathMode.trueFalse ||
        !canAnswer) {
      return;
    }
    _answer(answer == _math.isTrue);
  }

  void enterMathDigit(int digit) {
    if (exercise != Exercise.logic ||
        _mathMode != MathMode.calculate ||
        !canAnswer ||
        digit < 0 ||
        digit > 9 ||
        _mathInput.length >= 5) {
      return;
    }
    _mathInput = _mathInput == '0' ? '$digit' : '$_mathInput$digit';
    notifyListeners();
  }

  void deleteMathDigit() {
    if (exercise != Exercise.logic ||
        _mathMode != MathMode.calculate ||
        !canAnswer ||
        _mathInput.isEmpty) {
      return;
    }
    _mathInput = _mathInput.substring(0, _mathInput.length - 1);
    notifyListeners();
  }

  void submitMath() {
    if (exercise != Exercise.logic ||
        _mathMode != MathMode.calculate ||
        !canAnswer ||
        _mathInput.isEmpty) {
      return;
    }
    final correct = int.parse(_mathInput) == _math.answer;
    _answer(
      correct,
      feedbackDuration: Duration(milliseconds: correct ? 250 : 900),
    );
  }

  void answerSequence(int answer) {
    if (exercise != Exercise.sequence || !canAnswer) return;
    if (!_sequence.options.contains(answer)) return;
    _answer(answer == _sequence.answer);
  }

  void answerRule(bool first) {
    if (exercise != Exercise.switching || !canAnswer) return;
    _answer(first == rulePrompt.firstIsCorrect);
  }

  /// Start measuring only once the green cue has actually been painted.
  void reactionCuePresented(int trial) {
    if (exercise != Exercise.reaction ||
        !canAnswer ||
        _reactionPhase != ReactionPhase.ready ||
        trial != _reactionTrial ||
        _reactionShownAt != null) {
      return;
    }
    _reactionShownAt = _elapsed;
  }

  void tapReaction() {
    if (exercise != Exercise.reaction || !canAnswer) return;
    final shownAt = _reactionShownAt;
    if (_reactionPhase != ReactionPhase.ready || shownAt == null) {
      _reactionPhase = ReactionPhase.tooSoon;
      _answer(false, feedbackDuration: const Duration(milliseconds: 900));
      return;
    }
    _reactionPhase = ReactionPhase.result;
    _answer(
      true,
      reactionTime: _elapsed - shownAt,
      feedbackDuration: const Duration(milliseconds: 900),
    );
  }

  void _answer(
    bool correct, {
    Duration? reactionTime,
    Duration feedbackDuration = const Duration(milliseconds: 250),
  }) {
    _updateRemaining();
    _scores[_index] = score.add(
      success: correct,
      earned: correct ? 10 : 0,
      reactionTime: reactionTime,
    );
    _feedback = correct;
    _nextPromptAt = _elapsed + feedbackDuration;
    notifyListeners();
  }

  void selectCell(int index) {
    if (exercise != Exercise.memory ||
        !canAnswer ||
        _memoryPhase != MemoryPhase.recalling ||
        index < 0 ||
        index >= gridSide * gridSide) {
      return;
    }
    if (!_selected.add(index)) return;
    _updateRemaining();
    if (_selected.length == memoryTileCount) {
      final matches = _selected.intersection(_targets).length;
      _scores[_index] = score.add(
        success: matches == memoryTileCount,
        earned: matches * 10,
      );
      _feedback = matches == memoryTileCount;
      _memoryPhase = MemoryPhase.feedback;
      _memoryDeadline = _elapsed + const Duration(milliseconds: 650);
    }
    notifyListeners();
  }

  void _updateRemaining() {
    final left = roundDuration - (_elapsed - _roundStartedAt);
    _timeUp = left <= Duration.zero;
    _remaining = _timeUp ? Duration.zero : left;
  }

  /// Discard the unanswered final prompt, including partially selected grids.
  void skipFinalQuestion() {
    if (_phase != WarmupPhase.playing || _paused) return;
    _updateRemaining();
    if (!_timeUp || _feedback != null) return;
    _finishRound();
  }

  void _tick() {
    if (_disposed || _paused || _phase != WarmupPhase.playing) return;
    _updateRemaining();
    if (exercise == Exercise.memory) {
      if (_elapsed >= _memoryDeadline) {
        switch (_memoryPhase) {
          case MemoryPhase.showing:
            _memoryPhase = MemoryPhase.recalling;
          case MemoryPhase.feedback:
            if (_timeUp) {
              _finishRound();
              return;
            }
            _feedback = null;
            _generatePrompt();
          case MemoryPhase.recalling:
            break;
        }
      }
    } else if (_nextPromptAt != null && _elapsed >= _nextPromptAt!) {
      if (_timeUp) {
        _finishRound();
        return;
      }
      _feedback = null;
      _nextPromptAt = null;
      _generatePrompt();
    } else if (exercise == Exercise.reaction &&
        _reactionPhase == ReactionPhase.waiting &&
        _elapsed >= _reactionDeadline) {
      _reactionPhase = ReactionPhase.ready;
    }
    notifyListeners();
  }

  void _finishRound() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _remaining = Duration.zero;
    _feedback = null;
    if (_index == exercises.length - 1) {
      _phase = WarmupPhase.finished;
    } else {
      _index++;
      _phase = WarmupPhase.ready;
    }
    notifyListeners();
  }

  void pause() {
    if (_phase != WarmupPhase.playing || _paused) return;
    _updateRemaining();
    _paused = true;
    _pausedAt = _elapsed;
    _stopwatch.stop();
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    // The production stopwatch freezes on pause. An injected monotonic clock
    // may keep running, so move its deadlines forward by the paused duration.
    final gap = _elapsed - _pausedAt;
    _roundStartedAt += gap;
    _memoryDeadline += gap;
    _reactionDeadline += gap;
    if (_nextPromptAt != null) _nextPromptAt = _nextPromptAt! + gap;
    _paused = false;
    // An interrupted flash gets a fresh pattern and the full preview duration.
    if (exercise == Exercise.memory && _memoryPhase == MemoryPhase.showing) {
      _generatePrompt();
    }
    // An interrupted reaction trial cannot produce a meaningful response time.
    if (exercise == Exercise.reaction && _feedback == null) {
      _generatePrompt();
    }
    _stopwatch.start();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
