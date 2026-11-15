import 'package:flutter/material.dart';

import '../domain/game.dart';
import '../domain/morning.dart';
import 'morning_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.scores,
    required this.saving,
    required this.saveFailed,
    required this.onRetry,
    required this.onDone,
    this.mode = TrainingMode.daily,
    this.difficulty = Difficulty.challenge,
    this.morningBefore,
    this.onReflection,
    this.initialIntention = '',
  });
  final List<GameScore> scores;
  final bool saving;
  final bool saveFailed;
  final VoidCallback onRetry;
  final VoidCallback onDone;
  final TrainingMode mode;
  final Difficulty difficulty;
  final EnergyLevel? morningBefore;
  final Future<void> Function(MorningReflection reflection)? onReflection;
  final String initialIntention;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final TextEditingController _intention = TextEditingController(
    text: widget.initialIntention,
  );
  EnergyLevel? _after;
  bool _reflectionSaving = false;
  bool _reflectionFailed = false;
  bool get _morning => widget.mode == TrainingMode.morning;
  bool get _hasReflection =>
      _after != null ||
      _intention.text.trim().isNotEmpty ||
      widget.initialIntention.isNotEmpty;

  Future<void> _finish() async {
    if (_reflectionSaving || widget.saving || (_morning && widget.saveFailed)) {
      return;
    }
    if (_morning && _hasReflection && widget.onReflection != null) {
      setState(() {
        _reflectionSaving = true;
        _reflectionFailed = false;
      });
      try {
        await widget.onReflection!(
          MorningReflection(after: _after, intention: _intention.text),
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            _reflectionFailed = true;
            _reflectionSaving = false;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() => _reflectionSaving = false);
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _intention.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.scores.fold(0, (sum, score) => sum + score.points);
    final busy = widget.saving || _reflectionSaving;
    final enabled = !busy && !widget.saveFailed;
    final done = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('finish-session'),
        style: _morning
            ? FilledButton.styleFrom(backgroundColor: Palette.amber)
            : null,
        onPressed: busy || (_morning && widget.saveFailed) ? null : _finish,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(
          busy
              ? 'Saving progress…'
              : _morning
              ? (_hasReflection ? 'Save & start my day' : 'Start my day')
              : 'Done',
        ),
      ),
    );
    final saveMessage = widget.saveFailed
        ? Row(
            children: [
              const Expanded(
                child: Text(
                  'Your progress could not be saved. Try again.',
                  style: TextStyle(fontSize: 12, color: Palette.error),
                ),
              ),
              TextButton(
                onPressed: busy ? null : widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          )
        : const SizedBox.shrink();

    return PopScope(
      canPop: !_reflectionSaving,
      child: PageShell(
        fillHeight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const SizedBox(height: 28),
            Eyebrow(
              widget.mode == TrainingMode.practice
                  ? 'Practice complete'
                  : 'Session complete',
              color: _morning ? Palette.amber : Palette.mint,
            ),
            const SizedBox(height: 12),
            Text(
              _morning
                  ? 'Morning warmup\ncomplete.'
                  : 'A little time.\nWell spent.',
              style: displayStyle(36),
            ),
            const SizedBox(height: 12),
            Text(
              _morning
                  ? 'You made time to ease into your day.'
                  : '${widget.mode.title} · ${widget.difficulty.title}',
              style: const TextStyle(color: Palette.muted, height: 1.5),
            ),
            if (_morning) ...[
              const SizedBox(height: 24),
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How awake do you feel now?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.morningBefore != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Before: ${widget.morningBefore!.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.muted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    EnergyChoices(
                      selected: _after,
                      onChanged: (value) => setState(() => _after = value),
                      keyPrefix: 'energy-after',
                      enabled: enabled,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'One thing for today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('morning-intention'),
                      controller: _intention,
                      enabled: enabled,
                      maxLength: 100,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'What would make today feel worthwhile?',
                        hintMaxLines: 2,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(14),
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Both optional. Saved only on this device.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_reflectionFailed)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Your check-in could not be saved. Try again.',
                    style: TextStyle(color: Palette.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              saveMessage,
              const SizedBox(height: 12),
              done,
              const SizedBox(height: 28),
              const Eyebrow('Your game results'),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 20),
            Text(
              '$total',
              style: displayStyle(_morning ? 36 : 56, color: Palette.mint),
            ),
            const SizedBox(height: 4),
            const Eyebrow('Total points'),
            const SizedBox(height: 24),
            SurfacePanel(
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(child: Eyebrow('Your session')),
                      Eyebrow('Points'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final score in widget.scores)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          ExerciseGlyph(score.exercise, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  score.exercise.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  score.exercise == Exercise.reaction
                                      ? _reactionSummary(score)
                                      : score.attempts == 0
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
                          const SizedBox(width: 8),
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
            if (!_morning) ...[
              const SizedBox(height: 16),
              if (widget.saveFailed)
                saveMessage
              else
                Text(
                  widget.mode == TrainingMode.practice
                      ? 'A little practice, whenever you feel like it.'
                      : 'Showing up is a good habit. Come back tomorrow.',
                  style: const TextStyle(fontSize: 12, color: Palette.muted),
                ),
              const SizedBox(height: 20),
              done,
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _reactionSummary(GameScore score) {
    final average = score.averageReaction;
    final falseStarts = score.attempts - score.correct;
    return [
      if (average != null)
        '${average.inMilliseconds} ms average · ${score.bestReaction!.inMilliseconds} ms best'
      else
        'No reactions recorded',
      '${score.correct} ${score.correct == 1 ? 'reaction' : 'reactions'} · $falseStarts ${falseStarts == 1 ? 'false start' : 'false starts'}',
    ].join('\n');
  }
}
