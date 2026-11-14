import 'package:characters/characters.dart';

import 'game.dart';

enum EnergyLevel {
  sleepy('Sleepy', Difficulty.standard),
  steady('Getting there', Difficulty.challenge),
  ready('Ready', Difficulty.expert);

  const EnergyLevel(this.title, this.suggestedDifficulty);
  final String title;
  final Difficulty suggestedDifficulty;
}

class MorningPlan {
  const MorningPlan({this.before, this.difficulty = Difficulty.challenge});
  final EnergyLevel? before;
  final Difficulty difficulty;
}

class MorningReflection {
  const MorningReflection({this.after, this.intention = ''});
  final EnergyLevel? after;
  final String intention;
}

/// A self-reported check-in, not a measurement of cognitive performance.
class MorningEntry {
  const MorningEntry({
    required this.id,
    required this.day,
    required this.points,
    this.before,
    this.after,
    this.intention = '',
  });

  factory MorningEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final day = json['day'];
    final points = json['points'];
    final intention = json['intention'] ?? '';
    if (id is! String ||
        id.isEmpty ||
        id.length > 64 ||
        day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        DateTime.tryParse(day)?.toIso8601String().substring(0, 10) != day ||
        points is! int ||
        points < 0 ||
        intention is! String ||
        intention.characters.length > 100) {
      throw const FormatException('Invalid morning entry');
    }
    EnergyLevel? energy(Object? value) {
      if (value == null) return null;
      for (final level in EnergyLevel.values) {
        if (level.name == value) return level;
      }
      throw const FormatException('Invalid morning check-in');
    }

    return MorningEntry(
      id: id,
      day: day,
      points: points,
      before: energy(json['before']),
      after: energy(json['after']),
      intention: intention,
    );
  }

  final String id;
  final String day;
  final int points;
  final EnergyLevel? before;
  final EnergyLevel? after;
  final String intention;

  MorningEntry reflect(MorningReflection reflection) {
    final note = reflection.intention.trim();
    if (note.characters.length > 100) {
      throw ArgumentError.value(note.characters.length, 'intention');
    }
    return MorningEntry(
      id: id,
      day: day,
      points: points,
      before: before,
      after: reflection.after,
      intention: note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'points': points,
    'before': before?.name,
    'after': after?.name,
    'intention': intention,
  };
}
