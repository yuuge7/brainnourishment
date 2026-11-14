import 'package:brain_nourishment/src/domain/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same-day replays count warmups, but only one streak day', () {
    final first = const ProgressStats().complete(
      DateTime(2026, 11, 14, 10),
      40,
    );
    final second = first.complete(DateTime(2026, 11, 14, 20), 30);
    expect(second.completed, 2);
    expect(second.streak, 1);
    expect(second.bestPoints, 40);
    expect(second.lastDay, '2026-11-14');
  });

  test('consecutive local calendar days extend streak; gaps reset it', () {
    final first = const ProgressStats().complete(
      DateTime(2026, 10, 24, 23),
      10,
    );
    final second = first.complete(DateTime(2026, 10, 25, 23), 20);
    expect(second.streak, 2);
    expect(second.streakOn(DateTime(2026, 10, 26)), 2);
    expect(second.streakOn(DateTime(2026, 10, 27)), 0);
    final afterGap = second.complete(DateTime(2026, 10, 28), 5);
    expect(afterGap.streak, 1);
    expect(afterGap.completed, 3);
  });

  test(
    'progress round trips and rejects malformed dates and negative counters',
    () {
      final stats = const ProgressStats().complete(DateTime(2026, 11, 14), 90);
      expect(ProgressStats.fromJson(stats.toJson()).toJson(), stats.toJson());
      for (final invalid in [
        '2026-02-31',
        'yesterday',
        '2026-11-14T00:00:00Z',
      ]) {
        expect(
          () => ProgressStats.fromJson({...stats.toJson(), 'lastDay': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => ProgressStats.fromJson({...stats.toJson(), 'completed': -1}),
        throwsFormatException,
      );
    },
  );
}
