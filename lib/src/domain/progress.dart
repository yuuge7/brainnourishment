class ProgressStats {
  const ProgressStats({
    this.completed = 0,
    this.streak = 0,
    this.bestPoints = 0,
    this.lastDay,
  });

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'];
    final streak = json['streak'];
    final bestPoints = json['bestPoints'];
    final lastDay = json['lastDay'];
    if (completed is! int ||
        completed < 0 ||
        streak is! int ||
        streak < 0 ||
        bestPoints is! int ||
        bestPoints < 0 ||
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
    );
  }

  final int completed;
  final int streak;
  final int bestPoints;
  final String? lastDay;

  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  static String dayKey(DateTime date) =>
      _day(date).toIso8601String().substring(0, 10);

  int streakOn(DateTime now) {
    if (lastDay == null) return 0;
    final gap = _day(now)
        .difference(DateTime.parse('${lastDay}T00:00:00Z'))
        .inDays;
    return gap >= 0 && gap <= 1 ? streak : 0;
  }

  ProgressStats complete(DateTime now, int points) {
    final today = dayKey(now);
    final sameDay = today == lastDay;
    return ProgressStats(
      completed: completed + 1,
      streak: sameDay ? streak : streakOn(now) + 1,
      bestPoints: points > bestPoints ? points : bestPoints,
      lastDay: today,
    );
  }

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'streak': streak,
    'bestPoints': bestPoints,
    'lastDay': lastDay,
  };
}
