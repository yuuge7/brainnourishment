import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/game.dart';

enum WarmupPhase { ready, playing, finished }

enum MemoryPhase { showing, recalling, feedback }

/// Owns timing, question generation, scoring, and exercise transitions.
/// Widgets only render state and forward actions. No navigation or storage here.
class WarmupController extends ChangeNotifier {
  WarmupController({
    Random? random,
    this.roundDuration = const Duration(seconds: 30),
    Duration Function()? elapsed,
  }) : assert(roundDuration > Duration.zero),
       _random = random ?? Random(),
       _elapsedOverride = elapsed;

  final Duration roundDuration;
  final Random _random;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _disposed = false;
  final List<GameScore> _scores = [
    for (final exercise in Exercise.values) GameScore(exercise: exercise),
  ];

  WarmupPhase _phase = WarmupPhase.ready;
  WarmupPhase get phase => _phase;
  int _index = 0;
  Exercise get exercise => Exercise.values[_index];
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

  bool _paused = false;
  Duration _pausedAt = Duration.zero;
  bool get paused => _paused;
  bool? _feedback;
  bool? get feedback => _feedback;
  Duration? _nextPromptAt;
  StroopPrompt _stroop = const StroopPrompt(Ink.red, Ink.blue);
  StroopPrompt get stroop => _stroop;
  MathPrompt _math = const MathPrompt(14, 8, false, 5);
  MathPrompt get math => _math;
  MemoryPhase _memoryPhase = MemoryPhase.showing;
  MemoryPhase get memoryPhase => _memoryPhase;
  Set<int> _targets = {};
  Set<int> get targets => Set.unmodifiable(_targets);
  final Set<int> _selected = {};
  Set<int> get selected => Set.unmodifiable(_selected);
  Duration _memoryDeadline = Duration.zero;

  bool get canAnswer =>
      _phase == WarmupPhase.playing && !_paused && _feedback == null;

  void beginRound() {
    if (_phase != WarmupPhase.ready) return;
    _phase = WarmupPhase.playing;
    _paused = false;
    _stopwatch.start();
    _roundStartedAt = _elapsed;
    _remaining = roundDuration;
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
      case Exercise.logic:
        _math = MathPrompt.generate(_random);
      case Exercise.memory:
        final cells = List.generate(9, (index) => index)..shuffle(_random);
        _targets = cells.take(3).toSet();
        _selected.clear();
        _memoryPhase = MemoryPhase.showing;
        _memoryDeadline = _elapsed + const Duration(seconds: 1);
    }
  }

  void answerInk(Ink ink) {
    if (exercise != Exercise.focus || !canAnswer || !_withinTime()) return;
    _answer(ink == _stroop.ink);
  }

  void answerMath(bool answer) {
    if (exercise != Exercise.logic || !canAnswer || !_withinTime()) return;
    _answer(answer == _math.isTrue);
  }

  void _answer(bool correct) {
    _scores[_index] = score.add(success: correct, earned: correct ? 10 : 0);
    _feedback = correct;
    _nextPromptAt = _elapsed + const Duration(milliseconds: 250);
    notifyListeners();
  }

  void selectCell(int index) {
    if (exercise != Exercise.memory ||
        !canAnswer ||
        _memoryPhase != MemoryPhase.recalling ||
        index < 0 ||
        index > 8 ||
        !_withinTime()) {
      return;
    }
    if (!_selected.add(index)) return;
    if (_selected.length == 3) {
      final matches = _selected.intersection(_targets).length;
      _scores[_index] = score.add(success: matches == 3, earned: matches * 10);
      _feedback = matches == 3;
      _memoryPhase = MemoryPhase.feedback;
      _memoryDeadline = _elapsed + const Duration(milliseconds: 650);
    }
    notifyListeners();
  }

  bool _withinTime() {
    if (_elapsed - _roundStartedAt >= roundDuration) {
      _finishRound();
      return false;
    }
    return true;
  }

  void _tick() {
    if (_disposed || _paused || _phase != WarmupPhase.playing) return;
    if (!_withinTime()) return;
    _remaining = roundDuration - (_elapsed - _roundStartedAt);
    if (exercise == Exercise.memory) {
      if (_elapsed >= _memoryDeadline) {
        switch (_memoryPhase) {
          case MemoryPhase.showing:
            _memoryPhase = MemoryPhase.recalling;
          case MemoryPhase.feedback:
            _feedback = null;
            _generatePrompt();
          case MemoryPhase.recalling:
            break;
        }
      }
    } else if (_nextPromptAt != null && _elapsed >= _nextPromptAt!) {
      _feedback = null;
      _nextPromptAt = null;
      _generatePrompt();
    }
    notifyListeners();
  }

  void _finishRound() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _remaining = Duration.zero;
    // A partly entered grid counts as an attempt, without awarding extra points.
    if (exercise == Exercise.memory &&
        _memoryPhase == MemoryPhase.recalling &&
        _selected.isNotEmpty) {
      _scores[_index] = score.add(success: false, earned: 0);
    }
    _feedback = null;
    if (_index == Exercise.values.length - 1) {
      _phase = WarmupPhase.finished;
    } else {
      _index++;
      _phase = WarmupPhase.ready;
    }
    notifyListeners();
  }

  void pause() {
    if (_phase != WarmupPhase.playing || _paused) return;
    if (!_withinTime()) return;
    _remaining = roundDuration - (_elapsed - _roundStartedAt);
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
    if (_nextPromptAt != null) _nextPromptAt = _nextPromptAt! + gap;
    _paused = false;
    // An interrupted flash gets a fresh pattern and a full one-second look.
    if (exercise == Exercise.memory && _memoryPhase == MemoryPhase.showing) {
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
