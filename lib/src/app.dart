import 'package:flutter/material.dart';

import 'application/warmup_controller.dart';
import 'data/progress_repository.dart';
import 'domain/game.dart';
import 'domain/morning.dart';
import 'domain/progress.dart';
import 'presentation/home_screen.dart';
import 'presentation/morning_setup_screen.dart';
import 'presentation/theme.dart';
import 'presentation/warmup_screen.dart';

class BrainNourishmentApp extends StatefulWidget {
  const BrainNourishmentApp({
    super.key,
    this.repository,
    this.controllerFactory,
  });
  final ProgressRepository? repository;
  final WarmupController Function(
    TrainingMode mode,
    Difficulty difficulty,
    Exercise practiceExercise,
  )?
  controllerFactory;

  @override
  State<BrainNourishmentApp> createState() => _BrainNourishmentAppState();
}

class _BrainNourishmentAppState extends State<BrainNourishmentApp>
    with WidgetsBindingObserver {
  late final ProgressRepository _repository;
  ProgressStats _stats = const ProgressStats();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalProgressRepository();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await _repository.load();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Saved progress is unavailable. You can still play.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(
    BuildContext context,
    TrainingMode mode,
    Difficulty difficulty, {
    Exercise practiceExercise = Exercise.focus,
  }) async {
    MorningPlan? plan;
    if (mode == TrainingMode.morning) {
      plan = await Navigator.of(context).push<MorningPlan>(
        MaterialPageRoute(builder: (_) => const MorningSetupScreen()),
      );
      if (!mounted || !context.mounted || plan == null) return;
    }
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    ProgressStats? completion;
    Future<void> persist(ProgressStats stats) async {
      if (mounted) {
        setState(() {
          _stats = stats;
          _error = null;
        });
      }
      await _repository.save(stats);
    }

    final controller = widget.controllerFactory?.call(
      mode,
      plan?.difficulty ?? difficulty,
      practiceExercise,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WarmupScreen(
          controller: controller,
          mode: mode,
          difficulty: plan?.difficulty ?? difficulty,
          practiceExercise: practiceExercise,
          morningBefore: plan?.before,
          initialIntention: _stats.morningOn(DateTime.now())?.intention ?? '',
          onReflection: mode == TrainingMode.morning
              ? (reflection) async {
                  completion = completion!.reflect(sessionId, reflection);
                  await persist(completion!);
                }
              : null,
          onCompleted: (scores) async {
            if (mode == TrainingMode.practice) return;
            final now = DateTime.now();
            final points = scores.fold(0, (sum, score) => sum + score.points);
            // Retries write the same snapshot; one session increments the total once.
            completion ??= _stats.complete(
              now,
              points,
              morning: mode == TrainingMode.morning
                  ? MorningEntry(
                      id: sessionId,
                      day: ProgressStats.dayKey(now),
                      points: points,
                      before: plan?.before,
                      intention: _stats.morningOn(now)?.intention ?? '',
                    )
                  : null,
            );
            await persist(completion!);
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {}); // Refresh the local calendar day after a session.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Brain Nourishment',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: Builder(
      builder: (context) => HomeScreen(
        stats: _stats,
        loading: _loading,
        error: _error,
        onStart: (mode, difficulty) => _start(context, mode, difficulty),
        onPractice: (exercise, difficulty) => _start(
          context,
          TrainingMode.practice,
          difficulty,
          practiceExercise: exercise,
        ),
      ),
    ),
  );
}
