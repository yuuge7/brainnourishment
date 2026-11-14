import 'package:flutter/material.dart' hide Ink;

import '../../application/warmup_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class StroopGame extends StatelessWidget {
  const StroopGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Eyebrow('Tap the ink color'),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              controller.stroop.word.name.toUpperCase(),
              // The accessible label names the word without disclosing the answer.
              semanticsLabel:
                  'Word: ${controller.stroop.word.name}. Choose its ink color.',
              style: displayStyle(
                72,
                color: Palette.ink(controller.stroop.ink),
              ),
            ),
          ),
        ),
      ),
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 10),
        Row(
          children: [
            for (final ink in controller.inkChoices.skip(row * 2).take(2)) ...[
              if (ink != controller.inkChoices[row * 2])
                const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('ink-${ink.name}'),
                  onPressed: controller.canAnswer
                      ? () => controller.answerInk(ink)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.ink(ink),
                    backgroundColor: Palette.ink(ink).withValues(alpha: .07),
                    side: BorderSide(
                      color: Palette.ink(ink).withValues(alpha: .45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    ink.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ],
  );
}
