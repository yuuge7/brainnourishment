import 'package:flutter/material.dart';

import '../domain/game.dart';
import '../domain/progress.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.stats,
    required this.onStart,
    this.onPractice,
    this.loading = false,
    this.error,
    this.now,
  });
  final ProgressStats stats;
  final void Function(TrainingMode mode, Difficulty difficulty) onStart;
  final void Function(Exercise exercise, Difficulty difficulty)? onPractice;
  final bool loading;
  final String? error;
  final DateTime? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TrainingMode _mode = TrainingMode.daily;
  Difficulty _difficulty = Difficulty.challenge;

  Widget _difficultyChoices() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final difficulty in Difficulty.values)
        ChoiceChip(
          key: ValueKey('difficulty-${difficulty.name}'),
          label: Text(difficulty.title),
          selected: _difficulty == difficulty,
          onSelected: (_) => setState(() => _difficulty = difficulty),
          selectedColor: Palette.mint.withValues(alpha: .18),
          labelStyle: TextStyle(
            fontSize: 12,
            color: _difficulty == difficulty ? Palette.mint : Palette.muted,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final today = widget.stats.morningOn(now);
    return PageShell(
      fillHeight: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Brand(),
          const SizedBox(height: 28),
          Eyebrow(
            now.hour >= 4 && now.hour < 12
                ? 'Good morning'
                : 'Your morning ritual',
            color: Palette.amber,
          ),
          const SizedBox(height: 12),
          Text('Wake up\nat your pace.', style: displayStyle(38)),
          const SizedBox(height: 14),
          const Text(
            'A small routine before the day gets busy.',
            style: TextStyle(color: Palette.muted, height: 1.5),
          ),
          const SizedBox(height: 22),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      size: 32,
                      color: Palette.amber,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            today == null
                                ? 'Morning wake-up'
                                : 'You showed up today.',
                            style: displayStyle(22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            today == null
                                ? '90 seconds of play · builds up gently'
                                : 'Your morning is recorded. Another round is optional.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Memory',
                      style: TextStyle(color: Palette.mint, fontSize: 12),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Palette.muted,
                    ),
                    Text(
                      'Focus',
                      style: TextStyle(color: Palette.violet, fontSize: 12),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Palette.muted,
                    ),
                    Text(
                      'Math',
                      style: TextStyle(color: Palette.cyan, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('start-morning'),
                  onPressed: widget.loading
                      ? null
                      : () => widget.onStart(
                          TrainingMode.morning,
                          Difficulty.challenge,
                        ),
                  style: FilledButton.styleFrom(backgroundColor: Palette.amber),
                  icon: widget.loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    today == null
                        ? 'Start morning warmup'
                        : 'Repeat morning warmup',
                  ),
                ),
              ],
            ),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.error!,
                style: const TextStyle(fontSize: 12, color: Palette.error),
              ),
            ),
          if (today != null && today.intention.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Eyebrow('One thing for today', color: Palette.amber),
            const SizedBox(height: 8),
            Text(
              today.intention,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: Eyebrow('Your last 7 days')),
              Text(
                '${widget.stats.morningsThisWeek(now)}/7 mornings',
                style: const TextStyle(color: Palette.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MorningWeek(stats: widget.stats, now: now),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat('${widget.stats.morningDays}', 'mornings'),
              _Stat('${widget.stats.morningStreakOn(now)}', 'day streak'),
              _Stat('${widget.stats.completed}', 'all warmups'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'All-time best: ${widget.stats.bestPoints} points',
            style: const TextStyle(color: Palette.muted, fontSize: 11),
          ),
          if (widget.stats.mornings.isNotEmpty) ...[
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                final last = widget.stats.mornings.last;
                final checkIns = [
                  if (last.before != null) 'Before: ${last.before!.title}',
                  if (last.after != null) 'After: ${last.after!.title}',
                ];
                return checkIns.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        'Last check-in · ${checkIns.join(' · ')}',
                        style: const TextStyle(
                          color: Palette.muted,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      );
              },
            ),
          ],
          const SizedBox(height: 24),
          ExpansionTile(
            key: const ValueKey('other-modes'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 18),
            title: const Text(
              'More ways to play',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Daily, full circuit, or sprint',
              style: TextStyle(fontSize: 11, color: Palette.muted),
            ),
            children: [
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final mode in [
                    TrainingMode.daily,
                    TrainingMode.circuit,
                    TrainingMode.sprint,
                  ])
                    ChoiceChip(
                      key: ValueKey('mode-${mode.name}'),
                      label: Text('${mode.title} · ${mode.totalSeconds}s'),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _mode.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Palette.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Eyebrow('Difficulty'),
              ),
              const SizedBox(height: 8),
              _difficultyChoices(),
              const SizedBox(height: 8),
              Text(
                _difficulty.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Palette.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.loading
                      ? null
                      : () => widget.onStart(_mode, _difficulty),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(switch (_mode) {
                    TrainingMode.daily => 'Start Daily Warmup',
                    TrainingMode.circuit => 'Start Full Circuit',
                    _ => 'Start Sprint',
                  }),
                ),
              ),
            ],
          ),
          ExpansionTile(
            key: const ValueKey('practice-games'),
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Practice one game',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Pick any game for a 30-second round',
              style: TextStyle(fontSize: 11, color: Palette.muted),
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final difficulty in Difficulty.values)
                    ChoiceChip(
                      key: ValueKey('practice-difficulty-${difficulty.name}'),
                      label: Text(difficulty.title),
                      selected: _difficulty == difficulty,
                      onSelected: (_) =>
                          setState(() => _difficulty = difficulty),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final exercise in Exercise.values)
                ListTile(
                  key: ValueKey('practice-${exercise.name}'),
                  contentPadding: EdgeInsets.zero,
                  leading: ExerciseGlyph(exercise, size: 36),
                  title: Text(
                    exercise.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    exercise == Exercise.logic
                        ? 'True or false · calculate it'
                        : exercise == Exercise.reaction
                        ? 'Tap on green · response time in ms'
                        : exercise.skill,
                    style: const TextStyle(fontSize: 11, color: Palette.muted),
                  ),
                  trailing: const Icon(Icons.play_arrow_rounded, size: 22),
                  onTap: widget.loading || widget.onPractice == null
                      ? null
                      : () => widget.onPractice!(exercise, _difficulty),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Practice is separate from completed warmups and morning streaks.',
                  style: TextStyle(
                    color: Palette.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MorningWeek extends StatelessWidget {
  const _MorningWeek({required this.stats, required this.now});
  final ProgressStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 6; i >= 0; i--)
        Expanded(
          child: Builder(
            builder: (context) {
              final day = DateTime(now.year, now.month, now.day - i);
              final done = stats.morningCompletedOn(day);
              return Semantics(
                label:
                    '${day.day}/${day.month}: ${done ? 'morning completed' : 'no morning completed'}${i == 0 ? ', today' : ''}',
                child: Column(
                  children: [
                    Text(
                      const [
                        'Mo',
                        'Tu',
                        'We',
                        'Th',
                        'Fr',
                        'Sa',
                        'Su',
                      ][day.weekday - 1],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Palette.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Palette.amber : Palette.surface,
                        border: Border.all(
                          color: done || i == 0
                              ? Palette.amber
                              : Palette.border,
                        ),
                      ),
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              color: Palette.background,
                              size: 18,
                            )
                          : Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 11,
                                color: i == 0 ? Palette.amber : Palette.muted,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: displayStyle(25)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Palette.muted)),
      ],
    ),
  );
}
