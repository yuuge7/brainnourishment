import 'dart:async';

import 'package:flutter/material.dart';

import '../application/warmup_controller.dart';
import '../domain/game.dart';
import 'games/math_game.dart';
import 'games/memory_game.dart';
import 'games/stroop_game.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class WarmupScreen extends StatefulWidget {
  const WarmupScreen({super.key, required this.onCompleted, this.controller});
  final Future<void> Function(List<GameScore> scores) onCompleted;
  final WarmupController? controller;

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
    _controller = widget.controller ?? WarmupController();
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
              saving: _saving,
              saveFailed: _saveFailed,
              onRetry: _save,
              onDone: () => Navigator.pop(context),
            )
          : PageShell(
              minimumHeight: 344,
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 14),
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
      const SizedBox(width: 8),
      const Eyebrow('Daily warmup'),
      const Spacer(),
      for (final exercise in Exercise.values) ...[
        if (exercise.index > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(width: 20, child: Divider(color: Palette.border)),
          ),
        Icon(
          exercise.index < _controller.exercise.index
              ? Icons.check_circle_rounded
              : Palette.icon(exercise),
          size: 18,
          color: exercise.index <= _controller.exercise.index
              ? Palette.accent(exercise)
              : Palette.border,
        ),
      ],
      const Spacer(),
      if (_controller.phase == WarmupPhase.playing)
        IconButton(
          onPressed: _controller.pause,
          tooltip: 'Pause warmup',
          icon: const Icon(Icons.pause_rounded),
        )
      else
        const SizedBox(width: 48),
    ],
  );

  Widget _brief() {
    final exercise = _controller.exercise;
    final accent = Palette.accent(exercise);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                '0${exercise.index + 1} / 03 · ${exercise.skill}',
                color: accent,
              ),
              const SizedBox(height: 14),
              Text(exercise.title, style: displayStyle(36)),
              const SizedBox(height: 10),
              Text(
                exercise.subtitle,
                style: const TextStyle(fontSize: 13, color: Palette.muted),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Text(
                  switch (exercise) {
                    Exercise.focus => 'Tap the button that matches the text’s color. The word itself is a distraction.',
                    Exercise.logic => 'Check each equation, then choose True or False. Addition and subtraction only.',
                    Exercise.memory => 'Three tiles light up for one second. When they go dark, tap the same three tiles.',
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.muted,
                    height: 1.7,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _controller.beginRound,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Begin ${exercise.skill.toLowerCase()}'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 36),
        Expanded(
          flex: 5,
          child: SurfacePanel(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (exercise.index > 0) ...[
                  const Eyebrow('Previous round complete', color: Palette.mint),
                  const SizedBox(height: 16),
                ],
                ExerciseGlyph(exercise, size: 68),
                const SizedBox(height: 16),
                Text('30 seconds', style: displayStyle(28)),
                const SizedBox(height: 8),
                Text(
                  exercise == Exercise.memory
                      ? '10 points per remembered tile'
                      : '10 points per correct answer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Palette.muted),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The timer starts when you’re ready.',
                  style: TextStyle(fontSize: 10, color: Palette.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _playing() {
    final exercise = _controller.exercise;
    final accent = Palette.accent(exercise);
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    '0${exercise.index + 1} / 03 · ${exercise.skill}',
                    color: accent,
                  ),
                  const SizedBox(height: 10),
                  Text(exercise.title, style: displayStyle(26)),
                  const Spacer(),
                  Text(
                    '00:${_controller.secondsLeft.toString().padLeft(2, '0')}',
                    style: displayStyle(
                      42,
                      color: _controller.secondsLeft <= 5
                          ? Palette.error
                          : Palette.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _controller.fractionLeft,
                    color: accent,
                    backgroundColor: Palette.border,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: accent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${_controller.score.points}',
                        style: displayStyle(23),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'points',
                        style: TextStyle(fontSize: 11, color: Palette.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 20,
                    child: Text(
                      _controller.feedback == null
                          ? 'Find your rhythm.'
                          : _controller.feedback!
                          ? 'Nice work ✓'
                          : 'Keep going ↻',
                      style: TextStyle(
                        fontSize: 11,
                        color: _controller.feedback == false
                            ? Palette.error
                            : Palette.mint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 8,
              child: SurfacePanel(
                child: switch (exercise) {
                  Exercise.focus => StroopGame(controller: _controller),
                  Exercise.logic => MathGame(controller: _controller),
                  Exercise.memory => MemoryGame(controller: _controller),
                },
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
                    size: 34,
                    color: Palette.mint,
                  ),
                  const SizedBox(height: 12),
                  Text('Take a breath.', style: displayStyle(30)),
                  const SizedBox(height: 8),
                  const Text(
                    'Your timer is paused.',
                    style: TextStyle(fontSize: 12, color: Palette.muted),
                  ),
                  const SizedBox(height: 20),
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
