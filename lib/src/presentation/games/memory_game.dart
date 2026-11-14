import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class MemoryGame extends StatelessWidget {
  const MemoryGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(switch (controller.memoryPhase) {
              MemoryPhase.showing => 'Look closely',
              MemoryPhase.recalling => 'Your turn',
              MemoryPhase.feedback => 'The pattern',
            }, color: Palette.mint),
            const SizedBox(height: 12),
            Text(switch (controller.memoryPhase) {
              MemoryPhase.showing => 'Remember\nthese 3 tiles.',
              MemoryPhase.recalling => 'Tap the 3 tiles\nyou remember.',
              MemoryPhase.feedback =>
                controller.feedback!
                    ? 'All three.\nNicely done.'
                    : 'A fresh pattern\nis up next.',
            }, style: displayStyle(24)),
            const SizedBox(height: 14),
            Text(
              controller.memoryPhase == MemoryPhase.recalling
                  ? '${controller.selected.length} of 3 selected'
                  : '1 second to remember',
              style: const TextStyle(fontSize: 11, color: Palette.muted),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final selected = controller.selected.contains(index);
                    final reveal =
                        controller.memoryPhase != MemoryPhase.recalling;
                    final target = controller.targets.contains(index);
                    final highlighted = reveal ? target : selected;
                    final wrong =
                        controller.memoryPhase == MemoryPhase.feedback &&
                        selected &&
                        !target;
                    final color = wrong ? Palette.error : Palette.mint;
                    return Semantics(
                      label: 'Row ${index ~/ 3 + 1}, column ${index % 3 + 1}',
                      selected: selected,
                      child: Material(
                        color: highlighted || wrong
                            ? color.withValues(alpha: .85)
                            : Palette.background,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('cell-$index'),
                          onTap:
                              controller.memoryPhase == MemoryPhase.recalling &&
                                  controller.canAnswer
                              ? () => controller.selectCell(index)
                              : null,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: highlighted || wrong
                                    ? color
                                    : Palette.border,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: selected
                                ? Icon(
                                    wrong
                                        ? Icons.close_rounded
                                        : Icons.check_rounded,
                                    color: Palette.background,
                                    size: 22,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
