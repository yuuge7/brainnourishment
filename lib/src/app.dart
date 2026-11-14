import 'package:flutter/material.dart';

import 'data/progress_repository.dart';
import 'domain/progress.dart';
import 'presentation/home_screen.dart';
import 'presentation/theme.dart';
import 'presentation/warmup_screen.dart';

class BrainNourishmentApp extends StatefulWidget {
  const BrainNourishmentApp({super.key, this.repository});
  final ProgressRepository? repository;

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

  Future<void> _start(BuildContext context) async {
    ProgressStats? completion;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WarmupScreen(
          onCompleted: (scores) async {
            // Retries write the same snapshot; one session increments the total once.
            completion ??= _stats.complete(
              DateTime.now(),
              scores.fold(0, (sum, score) => sum + score.points),
            );
            if (mounted) {
              setState(() {
                _stats = completion!;
                _error = null;
              });
            }
            await _repository.save(completion!);
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
        onStart: () => _start(context),
      ),
    ),
  );
}
