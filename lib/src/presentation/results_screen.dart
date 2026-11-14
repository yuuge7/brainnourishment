import 'package:flutter/material.dart';

import '../domain/game.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.scores,
    required this.saving,
    required this.saveFailed,
    required this.onRetry,
    required this.onDone,
  });

  final List<GameScore> scores;
  final bool saving;
  final bool saveFailed;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final total = scores.fold(0, (sum, score) => sum + score.points);
    return PageShell(
      minimumHeight: 344,
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: Brand()),
              Eyebrow('Session complete', color: Palette.mint),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 32,
                        color: Palette.mint,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'A little time.\nWell spent.',
                              style: displayStyle(35),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your daily warmup is complete.',
                        style: TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$total',
                              style: displayStyle(42, color: Palette.mint),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 6),
                              child: Eyebrow('Total points'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: saving ? null : onDone,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(saving ? 'Saving progress…' : 'Done'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(
                        child: SurfacePanel(
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Eyebrow('Your session'),
                                  Spacer(),
                                  Eyebrow('Points'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final score in scores)
                                Expanded(
                                  child: Row(
                                    children: [
                                      ExerciseGlyph(score.exercise, size: 34),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              score.exercise.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              score.attempts == 0
                                                  ? 'No answers this round'
                                                  : '${score.correct}/${score.attempts} ${score.exercise == Exercise.memory ? 'patterns' : 'correct'} · ${(score.accuracy * 100).round()}%',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Palette.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${score.points}',
                                        style: displayStyle(
                                          26,
                                          color: Palette.accent(score.exercise),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (saveFailed)
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Progress is only saved for this visit. Try saving again.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Palette.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: saving ? null : onRetry,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Showing up is a good habit. Come back tomorrow.',
                          style: TextStyle(fontSize: 10, color: Palette.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
