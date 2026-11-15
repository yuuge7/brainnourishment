import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/warmup_controller.dart';
import '../../domain/game.dart';
import '../theme.dart';
import '../widgets.dart';

class MathGame extends StatelessWidget {
  const MathGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) =>
      controller.mathMode == MathMode.calculate
      ? _calculation()
      : Column(
          children: [
            const Eyebrow('True or false?'),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    controller.math.equation,
                    style: displayStyle(54),
                  ),
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

  Widget _calculation() => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final digit = int.tryParse(event.character ?? '');
      if (digit != null) {
        controller.enterMathDigit(digit);
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        controller.deleteMathDigit();
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        controller.submitMath();
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(
          controller.feedback == false
              ? 'Answer: ${controller.math.answer}'
              : 'Calculate it',
          color: controller.feedback == false ? Palette.error : Palette.cyan,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${controller.math.expression} = ?',
                    style: displayStyle(36),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Your answer',
                  value: controller.mathInput.isEmpty
                      ? 'Empty'
                      : controller.mathInput,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 120),
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Palette.cyan, width: 2),
                      ),
                    ),
                    child: Text(
                      controller.mathInput.isEmpty ? '…' : controller.mathInput,
                      key: const ValueKey('math-input'),
                      textAlign: TextAlign.center,
                      style: displayStyle(40, color: Palette.cyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(child: _key(row, col)),
              ],
            ],
          ),
        ],
      ],
    ),
  );

  Widget _key(int row, int col) {
    if (row == 3 && col == 0) {
      return OutlinedButton(
        key: const ValueKey('math-delete'),
        onPressed: controller.canAnswer && controller.mathInput.isNotEmpty
            ? controller.deleteMathDigit
            : null,
        child: const Icon(
          Icons.backspace_outlined,
          semanticLabel: 'Delete digit',
          size: 20,
        ),
      );
    }
    if (row == 3 && col == 2) {
      return FilledButton(
        key: const ValueKey('math-submit'),
        style: FilledButton.styleFrom(backgroundColor: Palette.cyan),
        onPressed: controller.canAnswer && controller.mathInput.isNotEmpty
            ? controller.submitMath
            : null,
        child: const Icon(Icons.check_rounded, semanticLabel: 'Check answer'),
      );
    }
    final digit = row == 3 ? 0 : row * 3 + col + 1;
    return OutlinedButton(
      key: ValueKey('math-digit-$digit'),
      onPressed: controller.canAnswer
          ? () => controller.enterMathDigit(digit)
          : null,
      child: Text(
        '$digit',
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
    );
  }
}
