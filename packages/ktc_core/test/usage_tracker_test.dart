import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  const second = Duration(seconds: 1);

  test('counts only while a game runs', () {
    final tracker = UsageTracker(limit: const Duration(hours: 1))
      ..tick(second, gameRunning: true)
      ..tick(second, gameRunning: false)
      ..tick(second, gameRunning: true);

    expect(tracker.used, const Duration(seconds: 2));
    expect(tracker.remaining, const Duration(minutes: 59, seconds: 58));
  });

  test('ignores sleep gaps', () {
    // The PC slept for an hour with a game open: that hour must not be counted.
    final tracker = UsageTracker(limit: const Duration(hours: 1))
      ..tick(const Duration(hours: 1), gameRunning: true);

    expect(tracker.used, Duration.zero);
  });

  test('raises each warning once, then time up', () {
    final tracker = UsageTracker(limit: const Duration(minutes: 15));
    final events = [
      for (var i = 0; i < 16 * 60; i++) tracker.tick(second, gameRunning: true),
    ].where((event) => event != TrackerEvent.none).toList();

    expect(events, [
      TrackerEvent.warning10Min,
      TrackerEvent.warning5Min,
      TrackerEvent.warning1Min,
      TrackerEvent.timeUp,
    ]);
    expect(tracker.timeUp, isTrue);
    expect(tracker.remaining, Duration.zero);
  });

  test('restored usage does not repeat passed warnings', () {
    // After a restart with 4 minutes left, the 10 and 5 minute warnings are not shown again.
    final tracker = UsageTracker(
      limit: const Duration(hours: 1),
      used: const Duration(minutes: 56),
    );

    expect(tracker.tick(second, gameRunning: true), TrackerEvent.none);
  });

  test('extra time from the parent extends the limit', () {
    final tracker = UsageTracker(
      limit: const Duration(minutes: 1),
      used: const Duration(minutes: 1),
    );
    expect(tracker.timeUp, isTrue);

    tracker.addTime(const Duration(minutes: 15));

    expect(tracker.timeUp, isFalse);
    expect(tracker.remaining, const Duration(minutes: 15));
  });
}
