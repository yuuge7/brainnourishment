import 'package:flutter/material.dart';

import '../domain/game.dart';
import '../domain/progress.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.stats,
    required this.onStart,
    this.loading = false,
    this.error,
  });

  final ProgressStats stats;
  final VoidCallback onStart;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) => PageShell(
    minimumHeight: 370,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Brand()),
            const Icon(Icons.wb_sunny_outlined, color: Palette.mint, size: 16),
            const SizedBox(width: 8),
            const Eyebrow('Your daily reset'),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow(
                        'Small habit. Fresh perspective.',
                        color: Palette.mint,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'A little sharper.\nEvery day.',
                              style: displayStyle(46),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Three quick exercises for your focus,\nlogic, and memory.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Palette.muted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: loading ? null : onStart,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Start Daily Warmup'),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 22,
                        runSpacing: 8,
                        children: [
                          _Stat(
                            '${stats.completed}',
                            'warmups',
                            Icons.check_circle_outline_rounded,
                          ),
                          _Stat(
                            '${stats.streakOn(DateTime.now())}',
                            'day streak',
                            Icons.local_fire_department_outlined,
                          ),
                          _Stat(
                            '${stats.bestPoints}',
                            'best score',
                            Icons.bolt_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: 9,
                child: SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow("Today's warmup"),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Column(
                          children: [
                            for (final exercise in Exercise.values)
                              Expanded(child: _ExercisePreview(exercise)),
                          ],
                        ),
                      ),
                      const Divider(color: Palette.border, height: 20),
                      Row(
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 25,
                            child: CustomPaint(painter: NeuralPaths()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                children: [
                                  Text(
                                    '01:30',
                                    style: displayStyle(
                                      22,
                                      color: Palette.mint,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'active time',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: Palette.muted),
      const SizedBox(width: 6),
      Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Palette.muted)),
    ],
  );
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview(this.exercise);
  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExerciseGlyph(exercise, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              '${exercise.skill} · 30 seconds',
              style: const TextStyle(fontSize: 10, color: Palette.muted),
            ),
          ],
        ),
      ),
      Text(
        '0${exercise.index + 1}',
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 12,
          color: Palette.muted,
        ),
      ),
    ],
  );
}
