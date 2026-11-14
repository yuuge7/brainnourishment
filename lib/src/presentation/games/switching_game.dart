import 'package:flutter/material.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';

class SwitchingGame extends StatelessWidget {
  const SwitchingGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        controller.rulePrompt.instruction,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Palette.peach,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Check the rule every time',
        textAlign: TextAlign.center,
        style: TextStyle(color: Palette.muted, fontSize: 11),
      ),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${controller.rulePrompt.number}',
              style: displayStyle(80),
            ),
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('rule-first'),
              onPressed: controller.canAnswer
                  ? () => controller.answerRule(true)
                  : null,
              child: Text(controller.rulePrompt.firstLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('rule-second'),
              onPressed: controller.canAnswer
                  ? () => controller.answerRule(false)
                  : null,
              child: Text(controller.rulePrompt.secondLabel),
            ),
          ),
        ],
      ),
    ],
  );
}
