import 'morning.dart';

class ProgressStats {
  const ProgressStats({
    this.completed = 0,
    this.streak = 0,
    this.bestPoints = 0,
    this.lastDay,
    this.morningDays = 0,
    this.morningStreak = 0,
    this.lastMorningDay,
    this._mornings = const [],
  });

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'];
    final streak = json['streak'];
    final bestPoints = json['bestPoints'];
    final lastDay = json['lastDay'];
    final mornings = json['mornings'] ?? const [];
    final morningDays = json['morningDays'] ?? 0;
    final morningStreak = json['morningStreak'] ?? 0;
    final lastMorningDay = json['lastMorningDay'];
    if (completed is! int ||
        completed < 0 ||
        streak is! int ||
        streak < 0 ||
        bestPoints is! int ||
        bestPoints < 0 ||
        morningDays is! int ||
        morningDays < 0 ||
        morningStreak is! int ||
        morningStreak < 0 ||
        (lastMorningDay != null &&
            (lastMorningDay is! String || !_validDay(lastMorningDay))) ||
        mornings is! List ||
        mornings.length > 60 ||
        (lastDay != null &&
            (lastDay is! String ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lastDay) ||
                DateTime.tryParse(lastDay) == null ||
                dayKey(DateTime.parse(lastDay)) != lastDay))) {
      throw const FormatException('Invalid saved progress');
    }
    return ProgressStats(
      completed: completed,
      streak: streak,
      bestPoints: bestPoints,
      lastDay: lastDay as String?,
      morningDays: morningDays,
      morningStreak: morningStreak,
      lastMorningDay: lastMorningDay as String?,
      mornings: [
        for (final entry in mornings)
          if (entry is Map<String, dynamic>)
            MorningEntry.fromJson(entry)
          else
            throw const FormatException('Invalid morning history'),
      ],
    );
  }

  final int completed;
  final int streak;
  final int bestPoints;
  final String? lastDay;
  final int morningDays;
  final int morningStreak;
  final String? lastMorningDay;
  final List<MorningEntry> _mornings;
  List<MorningEntry> get mornings => List.unmodifiable(_mornings);
  bool morningCompletedOn(DateTime date) =>
      _mornings.any((entry) => entry.day == dayKey(date));

  MorningEntry? morningOn(DateTime date) {
    for (final entry in _mornings.reversed) {
      if (entry.day == dayKey(date)) return entry;
    }
    return null;
  }

  int morningStreakOn(DateTime now) {
    if (lastMorningDay == null) return 0;
    final gap = _day(now)
        .difference(DateTime.parse('${lastMorningDay}T00:00:00Z'))
        .inDays;
    return gap >= 0 && gap <= 1 ? morningStreak : 0;
  }

  int morningsThisWeek(DateTime now) => List.generate(
    7,
    (i) => _day(now).subtract(Duration(days: i)),
  ).where(morningCompletedOn).length;

  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  static bool _validDay(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value)?.toIso8601String().substring(0, 10) == value;
  static String dayKey(DateTime date) =>
      _day(date).toIso8601String().substring(0, 10);

  int streakOn(DateTime now) {
    if (lastDay == null) return 0;
    final gap = _day(now)
        .difference(DateTime.parse('${lastDay}T00:00:00Z'))
        .inDays;
    return gap >= 0 && gap <= 1 ? streak : 0;
  }

  ProgressStats complete(DateTime now, int points, {MorningEntry? morning}) {
    final today = dayKey(now);
    final sameDay = today == lastDay;
    if (morning != null && morning.day != today) {
      throw ArgumentError('Morning entry must match the completion day');
    }
    final recent = [
      for (final entry in _mornings)
        if (entry.day != morning?.day) entry,
      ?morning,
    ];
    return ProgressStats(
      completed: completed + 1,
      streak: sameDay ? streak : streakOn(now) + 1,
      bestPoints: points > bestPoints ? points : bestPoints,
      lastDay: today,
      morningDays:
          morningDays + (morning != null && lastMorningDay != today ? 1 : 0),
      morningStreak: morning == null
          ? morningStreak
          : today == lastMorningDay
          ? morningStreak
          : morningStreakOn(now) + 1,
      lastMorningDay: morning == null ? lastMorningDay : today,
      mornings: recent
          .skip(recent.length > 60 ? recent.length - 60 : 0)
          .toList(),
    );
  }

  ProgressStats reflect(String id, MorningReflection reflection) {
    if (!_mornings.any((entry) => entry.id == id)) {
      throw StateError('Morning entry not found');
    }
    return ProgressStats(
      completed: completed,
      streak: streak,
      bestPoints: bestPoints,
      lastDay: lastDay,
      morningDays: morningDays,
      morningStreak: morningStreak,
      lastMorningDay: lastMorningDay,
      mornings: [
        for (final entry in _mornings)
          entry.id == id ? entry.reflect(reflection) : entry,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'streak': streak,
    'bestPoints': bestPoints,
    'lastDay': lastDay,
    'morningDays': morningDays,
    'morningStreak': morningStreak,
    'lastMorningDay': lastMorningDay,
    'mornings': [for (final entry in _mornings) entry.toJson()],
  };
}
