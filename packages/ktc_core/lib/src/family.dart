/// Firestore documents of the cloud part (stage 2). Schemas: `shared/schema`.
library;

final class Family {
  const Family({
    required this.id,
    required this.name,
    required this.parents,
    required this.deviceUids,
    required this.timeZone,
  });

  factory Family.fromJson(String id, Map<String, Object?> json) => Family(
    id: id,
    name: json['name']! as String,
    parents: (json['parents']! as List<Object?>).cast<String>(),
    deviceUids: (json['deviceUids'] as List<Object?>? ?? const [])
        .cast<String>(),
    timeZone: json['timeZone']! as String,
  );

  final String id;
  final String name;
  final List<String> parents;
  final List<String> deviceUids;
  final String timeZone;

  Map<String, Object?> toJson() => {
    'name': name,
    'parents': parents,
    'deviceUids': deviceUids,
    'timeZone': timeZone,
  };
}

/// A paired PC as reported by itself (`devices/{uid}`).
final class Device {
  const Device({
    required this.id,
    required this.name,
    required this.appVersion,
    required this.lastSeen,
    this.activeChildId,
  });

  factory Device.fromJson(String id, Map<String, Object?> json) => Device(
    id: id,
    name: json['name']! as String,
    appVersion: json['appVersion'] as String? ?? '',
    lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? ''),
    activeChildId: json['activeChildId'] as String?,
  );

  final String id;
  final String name;
  final String appVersion;

  /// `null` until the PC reports for the first time.
  final DateTime? lastSeen;
  final String? activeChildId;

  /// The PC reports every 5 minutes; a longer silence means it is off or cut off.
  bool isOnline(DateTime now) =>
      lastSeen != null &&
      now.difference(lastSeen!) < const Duration(minutes: 11);

  Map<String, Object?> toJson() => {
    'name': name,
    'appVersion': appVersion,
    'lastSeen': lastSeen?.toUtc().toIso8601String() ?? '',
    'activeChildId': activeChildId,
  };
}

final class UsageSession {
  const UsageSession({
    required this.start,
    required this.end,
    required this.deviceId,
  });

  factory UsageSession.fromJson(Map<String, Object?> json) => UsageSession(
    start: DateTime.parse(json['start']! as String),
    end: DateTime.parse(json['end']! as String),
    deviceId: json['deviceId']! as String,
  );

  final DateTime start;
  final DateTime end;
  final String deviceId;

  Map<String, Object?> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'deviceId': deviceId,
  };
}

/// Usage of one child on one local day (`usage/{childId}_{date}`).
final class DailyUsage {
  const DailyUsage({
    required this.childId,
    required this.date,
    required this.totalSeconds,
    this.apps = const {},
    this.sessions = const [],
  });

  factory DailyUsage.fromJson(Map<String, Object?> json) => DailyUsage(
    childId: json['childId']! as String,
    date: json['date']! as String,
    totalSeconds: json['totalSeconds']! as int,
    apps: (json['apps'] as Map<String, Object?>? ?? const {})
        .cast<String, int>(),
    sessions: [
      for (final session in json['sessions'] as List<Object?>? ?? const [])
        UsageSession.fromJson(session! as Map<String, Object?>),
    ],
  );

  static String documentId(String childId, String date) => '${childId}_$date';

  final String childId;

  /// `YYYY-MM-DD`, local to the family's time zone.
  final String date;

  /// Time with at least one game running (not the sum of [apps]).
  final int totalSeconds;

  /// Seconds per app id.
  final Map<String, int> apps;
  final List<UsageSession> sessions;

  Map<String, Object?> toJson() => {
    'childId': childId,
    'date': date,
    'totalSeconds': totalSeconds,
    'apps': apps,
    'sessions': [for (final session in sessions) session.toJson()],
  };
}
