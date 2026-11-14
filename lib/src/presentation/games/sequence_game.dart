import 'package:flutter/material.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class SequenceGame extends StatelessWidget {
  const SequenceGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Eyebrow('What comes next?'),
      Expanded(
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final term in controller.sequence.terms)
                Text('$term', style: displayStyle(32)),
              Text('?', style: displayStyle(42, color: Palette.amber)),
            ],
          ),
        ),
      ),
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 10),
        Row(
          children: [
            for (var col = 0; col < 2; col++) ...[
              if (col > 0) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey(
                    'sequence-${controller.sequence.options[row * 2 + col]}',
                  ),
                  onPressed: controller.canAnswer
                      ? () => controller.answerSequence(
                          controller.sequence.options[row * 2 + col],
                        )
                      : null,
                  child: Text(
                    '${controller.sequence.options[row * 2 + col]}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
