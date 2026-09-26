import 'package:ktc_core/ktc_core.dart';

/// Today's numbers for one child.
final class TodaySummary {
  const TodaySummary({
    required this.used,
    required this.limit,
    required this.apps,
  });

  final Duration used;
  final Duration limit;

  /// Seconds per app id, most played first.
  final List<MapEntry<String, int>> apps;

  Duration get remaining => used >= limit ? Duration.zero : limit - used;

  double get progress => limit == Duration.zero
      ? 1
      : (used.inSeconds / limit.inSeconds).clamp(0, 1).toDouble();
}

TodaySummary todaySummary(Child child, List<DailyUsage> usage, DateTime now) {
  final today = dateKey(now);
  final record = usage
      .where((u) => u.childId == child.id && u.date == today)
      .firstOrNull;
  final apps = (record?.apps.entries.toList() ?? [])
    ..sort((a, b) => b.value.compareTo(a.value));
  return TodaySummary(
    used: Duration(seconds: record?.totalSeconds ?? 0),
    limit: child.limitFor(now),
    apps: apps,
  );
}

/// Seconds played per day for the 7 days ending [now], oldest first; missing days are 0.
List<({DateTime day, int seconds})> weekFor(
  String childId,
  List<DailyUsage> usage,
  DateTime now,
) {
  final byDate = {
    for (final record in usage)
      if (record.childId == childId) record.date: record.totalSeconds,
  };
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var offset = 6; offset >= 0; offset--)
      () {
        final day = DateTime(today.year, today.month, today.day - offset);
        return (day: day, seconds: byDate[dateKey(day)] ?? 0);
      }(),
  ];
}

/// `1:05` for 65 minutes, `0:40` for 40 minutes.
String formatHoursMinutes(Duration duration) =>
    '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

/// Adds [extra] to today's bonus of [child], replacing a bonus from another day.
Child withBonus(Child child, Duration extra, DateTime now) {
  final today = dateKey(now);
  final current = child.bonus?.date == today ? child.bonus!.seconds : 0;
  return child.copyWith(
    bonus: Bonus(date: today, seconds: current + extra.inSeconds),
  );
}
