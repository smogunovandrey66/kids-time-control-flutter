/// Warnings raised by [UsageTracker], in the order they occur.
enum TrackerEvent { none, warning10Min, warning5Min, warning1Min, timeUp }

/// Time accounting for the active child.
///
/// The service calls [tick] about once per second with the time elapsed on a
/// monotonic clock (`Stopwatch`, `GetTickCount64`), so changing the system time
/// has no effect. Only "is any game running" is accounted: two games at once do
/// not consume time twice. Gaps longer than [maxTickGap] (sleep, hibernation)
/// are ignored.
final class UsageTracker {
  /// [used] is the time already used today (restored after a restart).
  UsageTracker({required Duration limit, Duration used = Duration.zero})
    : _limit = limit,
      _used = used {
    // Warnings whose thresholds were passed before a restart are not repeated.
    _lastEvent = _eventFor(remaining);
  }

  static const maxTickGap = Duration(seconds: 5);

  Duration _limit;
  Duration _used;
  late TrackerEvent _lastEvent;

  Duration get used => _used;

  Duration get remaining {
    final value = _limit - _used;
    return value.isNegative ? Duration.zero : value;
  }

  bool get timeUp => _used >= _limit;

  /// Returns a warning (or [TrackerEvent.timeUp]) once, when its threshold is
  /// crossed; otherwise [TrackerEvent.none].
  TrackerEvent tick(Duration elapsed, {required bool gameRunning}) {
    if (gameRunning && elapsed > Duration.zero && elapsed <= maxTickGap) {
      _used += elapsed;
    }

    final current = _eventFor(_limit - _used);
    if (current.index > _lastEvent.index) {
      _lastEvent = current;
      return current;
    }
    return TrackerEvent.none;
  }

  /// Extra time granted by the parent. Re-arms warnings above the new remainder.
  void addTime(Duration extra) {
    _limit += extra;
    _lastEvent = _eventFor(_limit - _used);
  }

  static TrackerEvent _eventFor(Duration remaining) => switch (remaining) {
    <= Duration.zero => TrackerEvent.timeUp,
    <= const Duration(minutes: 1) => TrackerEvent.warning1Min,
    <= const Duration(minutes: 5) => TrackerEvent.warning5Min,
    <= const Duration(minutes: 10) => TrackerEvent.warning10Min,
    _ => TrackerEvent.none,
  };
}
