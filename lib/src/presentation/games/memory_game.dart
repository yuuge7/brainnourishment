import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/warmup_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class MemoryGame extends StatelessWidget {
  const MemoryGame({super.key, required this.controller});
  final WarmupController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Eyebrow(switch (controller.memoryPhase) {
        MemoryPhase.showing => 'Look closely',
        MemoryPhase.recalling => 'Your turn',
        MemoryPhase.feedback => 'The pattern',
      }, color: Palette.mint),
      const SizedBox(height: 10),
      Text(
        switch (controller.memoryPhase) {
          MemoryPhase.showing =>
            'Remember these ${controller.memoryTileCount} tiles.',
          MemoryPhase.recalling =>
            'Tap the ${controller.memoryTileCount} tiles.',
          MemoryPhase.feedback =>
            controller.feedback! ? 'You got them all.' : 'Here’s the pattern.',
        },
        textAlign: TextAlign.center,
        style: displayStyle(22),
      ),
      const SizedBox(height: 8),
      Text(
        switch (controller.memoryPhase) {
          MemoryPhase.recalling =>
            '${controller.selected.length} of ${controller.memoryTileCount} selected',
          MemoryPhase.showing =>
            '${controller.memoryFlash.inMilliseconds / 1000}s to remember',
          MemoryPhase.feedback =>
            '${controller.selected.intersection(controller.targets).length} tiles remembered',
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Palette.muted),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            final columns = controller.gridSide;
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: columns * columns,
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
                      label:
                          'Row ${index ~/ columns + 1}, column ${index % columns + 1}',
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
