import 'package:flutter/material.dart';

import '../domain/game.dart';
import '../domain/morning.dart';
import 'morning_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

class MorningSetupScreen extends StatefulWidget {
  const MorningSetupScreen({super.key});

  @override
  State<MorningSetupScreen> createState() => _MorningSetupScreenState();
}

class _MorningSetupScreenState extends State<MorningSetupScreen> {
  EnergyLevel? _before;
  Difficulty _difficulty = Difficulty.challenge;
  final Set<int> _prepared = {};

  @override
  Widget build(BuildContext context) => PageShell(
    fillHeight: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Eyebrow('Morning wake-up', color: Palette.amber),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Start where\nyou are.', style: displayStyle(36)),
        const SizedBox(height: 12),
        const Text(
          '90 seconds of play. An easy first round, then a little more to think about.',
          style: TextStyle(color: Palette.muted, height: 1.6),
        ),
        const SizedBox(height: 26),
        const Text(
          'How awake do you feel?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        EnergyChoices(
          selected: _before,
          keyPrefix: 'energy-before',
          onChanged: (level) => setState(() {
            _before = level;
            _difficulty = level?.suggestedDifficulty ?? Difficulty.challenge;
          }),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional. Your choice suggests a finishing level; you can change it below.',
          style: TextStyle(fontSize: 11, color: Palette.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Eyebrow('Finish at'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final difficulty in Difficulty.values)
              ChoiceChip(
                key: ValueKey('morning-difficulty-${difficulty.name}'),
                label: Text(difficulty.title),
                selected: _difficulty == difficulty,
                onSelected: (_) => setState(() => _difficulty = difficulty),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          switch (_difficulty) {
            Difficulty.standard =>
              'Standard → Standard → Standard. Keep it gentle today.',
            Difficulty.challenge =>
              'Standard → Standard → Challenge. Ease in, then step up.',
            Difficulty.expert =>
              'Standard → Challenge → Expert. Build up one round at a time.',
          },
          style: const TextStyle(
            color: Palette.muted,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Eyebrow('A moment to settle in'),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 3; i++)
                CheckboxListTile(
                  value: _prepared.contains(i),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _prepared.add(i);
                    } else {
                      _prepared.remove(i);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: Palette.amber,
                  title: Text(
                    const [
                      'Sit up and put your feet down',
                      'Let in some daylight, if available',
                      'Take a comfortable breath',
                    ][i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'All optional. Start whenever you’re ready.',
                  style: TextStyle(color: Palette.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('begin-morning'),
          style: FilledButton.styleFrom(backgroundColor: Palette.amber),
          onPressed: () => Navigator.pop(
            context,
            MorningPlan(before: _before, difficulty: _difficulty),
          ),
          icon: const Icon(Icons.wb_sunny_outlined),
          label: const Text('Begin morning warmup'),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}
