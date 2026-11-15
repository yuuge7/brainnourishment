import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';

/// The cue changes in one frame; fading it would make the start ambiguous.
class ReactionGame extends StatefulWidget {
  const ReactionGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  State<ReactionGame> createState() => _ReactionGameState();
}

class _ReactionGameState extends State<ReactionGame> {
  @override
  void initState() {
    super.initState();
    _markCue();
  }

  @override
  void didUpdateWidget(ReactionGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _markCue();
  }

  void _markCue() {
    final controller = widget.controller;
    if (controller.reactionPhase != ReactionPhase.ready || controller.paused) {
      return;
    }
    final trial = controller.reactionTrial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.reactionCuePresented(trial);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final phase = controller.reactionPhase;
    final ready = phase == ReactionPhase.ready;
    final waiting = phase == ReactionPhase.waiting;
    final tooSoon = phase == ReactionPhase.tooSoon;
    final times = controller.score.reactionTimes;
    final title = switch (phase) {
      ReactionPhase.waiting => 'Wait for green',
      ReactionPhase.ready => 'Tap now!',
      ReactionPhase.tooSoon => 'Too soon',
      ReactionPhase.result => '${times.last.inMilliseconds} ms',
    };
    final hint = switch (phase) {
      ReactionPhase.waiting => 'Keep your finger ready.',
      ReactionPhase.ready => 'Green means go.',
      ReactionPhase.tooSoon =>
        controller.remaining == Duration.zero
            ? 'False start. No reaction time recorded.'
            : 'Wait for the color to change. Try again.',
      ReactionPhase.result =>
        controller.remaining == Duration.zero
            ? 'Last reaction recorded.'
            : 'Get ready for the next one.',
    };
    final color = ready
        ? const Color(0xFF62DDA6)
        : waiting
        ? const Color(0xFFA52D45)
        : Palette.background;
    final foreground = ready ? Palette.background : Palette.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FocusableActionDetector(
            autofocus: true,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
                  ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
                  ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  controller.tapReaction();
                  return null;
                },
              ),
            },
            child: Semantics(
              button: true,
              enabled: controller.canAnswer,
              label: title,
              hint: hint,
              onTap: controller.canAnswer ? controller.tapReaction : null,
              excludeSemantics: true,
              child: Listener(
                onPointerDown: controller.canAnswer
                    ? (_) => controller.tapReaction()
                    : null,
                child: Container(
                  key: const ValueKey('reaction-target'),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tooSoon ? Palette.error : color),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ready
                              ? Icons.touch_app_rounded
                              : waiting
                              ? Icons.more_horiz_rounded
                              : tooSoon
                              ? Icons.replay_rounded
                              : Icons.bolt_rounded,
                          size: 40,
                          color: foreground,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: displayStyle(32, color: foreground),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            _stat('Average', controller.score.averageReaction),
            _stat('Best', controller.score.bestReaction),
            Text(
              '${times.length} ${times.length == 1 ? 'reaction' : 'reactions'}',
              style: const TextStyle(fontSize: 11, color: Palette.muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, Duration? value) => Text(
    '$label  ${value == null ? '—' : '${value.inMilliseconds} ms'}',
    style: const TextStyle(fontSize: 11, color: Palette.muted),
  );
}
