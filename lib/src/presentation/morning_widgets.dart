import 'package:flutter/material.dart';

import '../domain/morning.dart';
import 'theme.dart';

class EnergyChoices extends StatelessWidget {
  const EnergyChoices({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.enabled = true,
  });
  final EnergyLevel? selected;
  final ValueChanged<EnergyLevel?> onChanged;
  final String keyPrefix;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final level in EnergyLevel.values)
        ChoiceChip(
          key: ValueKey('$keyPrefix-${level.name}'),
          label: Text(level.title),
          selected: selected == level,
          onSelected: enabled
              ? (value) => onChanged(value ? level : null)
              : null,
          selectedColor: Palette.amber.withValues(alpha: .16),
          side: BorderSide(
            color: selected == level ? Palette.amber : Palette.border,
          ),
          labelStyle: TextStyle(
            fontSize: 12,
            color: selected == level ? Palette.amber : Palette.muted,
          ),
        ),
    ],
  );
}
