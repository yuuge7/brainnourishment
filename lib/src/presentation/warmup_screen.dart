import 'dart:async';

import 'package:flutter/material.dart';

import '../application/warmup_controller.dart';
import '../domain/game.dart';
import '../domain/morning.dart';
import 'games/math_game.dart';
import 'games/memory_game.dart';
import 'games/sequence_game.dart';
import 'games/stroop_game.dart';
import 'games/switching_game.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class WarmupScreen extends StatefulWidget {
  const WarmupScreen({
    super.key,
    required this.onCompleted,
    this.controller,
    this.mode = TrainingMode.daily,
    this.difficulty = Difficulty.challenge,
    this.practiceExercise = Exercise.focus,
    this.morningBefore,
    this.onReflection,
    this.initialIntention = '',
  });
  final Future<void> Function(List<GameScore> scores) onCompleted;
  final WarmupController? controller;
  final TrainingMode mode;
  final Difficulty difficulty;
  final Exercise practiceExercise;
  final EnergyLevel? morningBefore;
  final Future<void> Function(MorningReflection reflection)? onReflection;
  final String initialIntention;

  @override
  State<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends State<WarmupScreen>
    with WidgetsBindingObserver {
  late final WarmupController _controller;
  bool _completionStarted = false;
  bool _saving = false;
  bool _saveFailed = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        WarmupController(
          mode: widget.mode,
          difficulty: widget.difficulty,
          practiceExercise: widget.practiceExercise,
        );
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onChanged() {
    if (_controller.phase == WarmupPhase.finished && !_completionStarted) {
      _completionStarted = true;
      unawaited(_save());
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onCompleted(_controller.scores);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final wasPaused = _controller.paused;
    _controller.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this warmup?'),
        content: const Text(
          'This session will not count toward your completed warmups.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End warmup'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted) return;
    if (leave == true) {
      Navigator.pop(context);
    } else if (!wasPaused) {
      _controller.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => PopScope(
      canPop: _controller.phase == WarmupPhase.finished && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _controller.phase != WarmupPhase.finished) {
          unawaited(_confirmExit());
        }
      },
      child: _controller.phase == WarmupPhase.finished
          ? ResultsScreen(
              scores: _controller.scores,
              mode: _controller.mode,
              difficulty: _controller.difficulty,
              morningBefore: widget.morningBefore,
              onReflection: widget.onReflection,
              initialIntention: widget.initialIntention,
              saving: _saving,
              saveFailed: _saveFailed,
              onRetry: _save,
              onDone: () => Navigator.pop(context),
            )
          : PageShell(
              minimumHeight: 660,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (
                        var i = 0;
                        i < _controller.exercises.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _controller.roundIndex
                                  ? Palette.accent(_controller.exercises[i])
                                  : Palette.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: _controller.phase == WarmupPhase.ready
                        ? _brief()
                        : _playing(),
                  ),
                ],
              ),
            ),
    ),
  );

  Widget _header() => Row(
    children: [
      IconButton(
        onPressed: _confirmExit,
        tooltip: 'End warmup',
        icon: const Icon(Icons.close_rounded),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_controller.mode.title} · ${_controller.roundDifficulty.title}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Round ${_controller.roundIndex + 1} of ${_controller.exercises.length}',
              style: const TextStyle(fontSize: 11, color: Palette.muted),
            ),
          ],
        ),
      ),
      if (_controller.phase == WarmupPhase.playing)
        IconButton(
          onPressed: _controller.paused ? null : _controller.pause,
          tooltip: 'Pause warmup',
          icon: const Icon(Icons.pause_rounded),
        ),
    ],
  );

  Widget _brief() {
    final exercise = _controller.exercise;
    final accent = Palette.accent(exercise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(exercise.skill, color: accent),
        const SizedBox(height: 10),
        Text(exercise.title, style: displayStyle(34)),
        const SizedBox(height: 10),
        Text(
          exercise.subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Palette.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SurfacePanel(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExerciseGlyph(exercise, size: 64),
                const SizedBox(height: 18),
                Text(
                  '${_controller.roundDuration.inSeconds} seconds',
                  style: displayStyle(28),
                ),
                const SizedBox(height: 10),
                Text(
                  exercise == Exercise.memory
                      ? '10 points per remembered tile'
                      : '10 points per correct answer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Palette.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _instructions(exercise),
          style: const TextStyle(
            fontSize: 13,
            color: Palette.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'The timer starts when you’re ready.',
          style: TextStyle(fontSize: 11, color: Palette.muted),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: _controller.beginRound,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text('Begin ${exercise.skill.toLowerCase()}'),
        ),
      ],
    );
  }

  String _instructions(Exercise exercise) => switch (exercise) {
    Exercise.focus =>
      'Tap the button that matches the text’s ink color. Ignore the word.${_controller.roundDifficulty == Difficulty.standard ? '' : ' The buttons change position each time.'}',
    Exercise.logic =>
      'Choose True or False for each equation. ${_controller.roundDifficulty == Difficulty.standard ? 'Addition and subtraction.' : 'Addition, subtraction, and multiplication.'}',
    Exercise.memory =>
      '${_controller.memoryTileCount} tiles light up for ${_controller.memoryFlash.inMilliseconds / 1000} seconds. When they go dark, tap the same tiles on the ${_controller.gridSide} × ${_controller.gridSide} grid.',
    Exercise.sequence =>
      'Find the next number in the sequence. ${switch (_controller.roundDifficulty) {
        Difficulty.standard => 'Look for a constant step.',
        Difficulty.challenge => 'Steps can stay the same or grow by one.',
        Difficulty.expert => 'Steps can stay the same, grow by one, or alternate.',
      }} Choose one of four answers.',
    Exercise.switching => 'The rule switches after every answer. Alternate between Even or Odd and Below or Above the displayed boundary. Read the rule each time.',
  };

  Widget _playing() {
    final exercise = _controller.exercise;
    final accent = Palette.accent(exercise);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(exercise.skill, color: accent),
                      const SizedBox(height: 8),
                      Text(exercise.title, style: displayStyle(26)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '00:${_controller.secondsLeft.toString().padLeft(2, '0')}',
                  style: displayStyle(
                    30,
                    color: _controller.secondsLeft <= 5
                        ? Palette.error
                        : Palette.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _controller.fractionLeft,
              color: accent,
              backgroundColor: Palette.border,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 14),
            Text(
              _controller.mode == TrainingMode.morning
                  ? 'Take your time. Accuracy comes first.'
                  : '${_controller.score.points} points',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SurfacePanel(
                padding: const EdgeInsets.all(16),
                child: switch (exercise) {
                  Exercise.focus => StroopGame(controller: _controller),
                  Exercise.logic => MathGame(controller: _controller),
                  Exercise.memory => MemoryGame(controller: _controller),
                  Exercise.sequence => SequenceGame(controller: _controller),
                  Exercise.switching => SwitchingGame(controller: _controller),
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _controller.feedback == null
                  ? 'Find your rhythm.'
                  : _controller.feedback!
                  ? 'Nice work ✓'
                  : 'Keep going ↻',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _controller.feedback == false
                    ? Palette.error
                    : Palette.mint,
              ),
            ),
          ],
        ),
        if (_controller.paused)
          Positioned.fill(
            child: SurfacePanel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 40,
                    color: Palette.mint,
                  ),
                  const SizedBox(height: 16),
                  Text('Take a breath.', style: displayStyle(30)),
                  const SizedBox(height: 10),
                  const Text(
                    'Your timer is paused.',
                    style: TextStyle(fontSize: 13, color: Palette.muted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _controller.resume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume warmup'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
