import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/game.dart';
import 'theme.dart';

/// Centers portrait content and lets short windows or enlarged text scroll.
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.child,
    this.minimumHeight = 300,
    this.fillHeight = true,
  });

  final Widget child;
  final double minimumHeight;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final height = math.max(
            constraints.maxHeight,
            minimumHeight * math.max(1, textScale),
          );
          return SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SizedBox(
                  height: fillHeight ? height : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 360 ? 16 : 24,
                      vertical: 16,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = Palette.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.8,
      color: color,
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Palette.mint.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.spa_outlined, color: Palette.mint, size: 21),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'brain nourishment',
          style: displayStyle(18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class ExerciseGlyph extends StatelessWidget {
  const ExerciseGlyph(this.exercise, {super.key, this.size = 40});
  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Palette.accent(exercise).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(
      Palette.icon(exercise),
      color: Palette.accent(exercise),
      size: size * .5,
    ),
  );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Palette.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Palette.border.withValues(alpha: .7)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// A quiet illustration of three cognitive paths joining into one warmup.
class NeuralPaths extends CustomPainter {
  const NeuralPaths();

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [Palette.violet, Palette.cyan, Palette.mint];
    for (var index = 0; index < 3; index++) {
      final y = size.height * (.22 + index * .28);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .35,
          y,
          size.width * .4,
          size.height * .5,
          size.width * .74,
          size.height * .5,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[index].withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(3, y), 3, Paint()..color = colors[index]);
    }
    final center = Offset(size.width * .8, size.height * .5);
    canvas.drawCircle(
      center,
      size.height * .15,
      Paint()..color = Palette.mint.withValues(alpha: .09),
    );
    canvas.drawCircle(center, size.height * .08, Paint()..color = Palette.mint);
    canvas.drawCircle(
      center,
      size.height * .22,
      Paint()
        ..color = Palette.mint.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant NeuralPaths oldDelegate) => false;
}
