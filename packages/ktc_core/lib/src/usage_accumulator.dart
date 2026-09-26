import 'family.dart';

/// Adds played time to a day's usage record.
///
/// [totalSeconds] grows once per tick while any game runs; every running app
/// gets the time too, so the per-app numbers may add up to more than the total
/// when two games run at once.
///
/// Takes whole [seconds]: the caller carries fractions over to the next tick,
/// so rounding does not drift.
DailyUsage accumulateUsage(
  DailyUsage usage,
  int seconds, {
  required Set<String> runningAppIds,
}) {
  if (runningAppIds.isEmpty || seconds <= 0) return usage;
  final apps = Map.of(usage.apps);
  for (final appId in runningAppIds) {
    apps[appId] = (apps[appId] ?? 0) + seconds;
  }
  return DailyUsage(
    childId: usage.childId,
    date: usage.date,
    totalSeconds: usage.totalSeconds + seconds,
    apps: apps,
    sessions: usage.sessions,
  );
}
