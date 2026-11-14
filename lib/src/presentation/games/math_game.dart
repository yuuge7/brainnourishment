import 'package:flutter/material.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class MathGame extends StatelessWidget {
  const MathGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Eyebrow('True or false?'),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(controller.math.equation, style: displayStyle(54)),
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.canAnswer
                  ? () => controller.answerMath(true)
                  : null,
              icon: const Icon(Icons.check_rounded, color: Palette.mint),
              label: const Text('True'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.canAnswer
                  ? () => controller.answerMath(false)
                  : null,
              icon: const Icon(Icons.close_rounded, color: Palette.error),
              label: const Text('False'),
            ),
          ),
        ],
      ),
    ],
  );
}
