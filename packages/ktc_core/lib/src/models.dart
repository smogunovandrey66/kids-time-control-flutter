/// Data types mirroring `shared/schema/*.schema.json`.
library;

/// Daily limits of a child, in seconds.
final class Limits {
  const Limits({
    required this.weekdaySeconds,
    required this.weekendSeconds,
    this.allowedFrom,
    this.allowedTo,
  });

  factory Limits.fromJson(Map<String, Object?> json) => Limits(
    weekdaySeconds: json['weekdaySeconds']! as int,
    weekendSeconds: json['weekendSeconds']! as int,
    allowedFrom: json['allowedFrom'] as String?,
    allowedTo: json['allowedTo'] as String?,
  );

  final int weekdaySeconds;
  final int weekendSeconds;

  /// Local time of day, `HH:mm`.
  final String? allowedFrom;
  final String? allowedTo;

  /// Limit for [date]: Saturday and Sunday use the weekend limit.
  int secondsFor(DateTime date) =>
      date.weekday >= DateTime.saturday ? weekendSeconds : weekdaySeconds;

  Map<String, Object?> toJson() => {
    'weekdaySeconds': weekdaySeconds,
    'weekendSeconds': weekendSeconds,
    'allowedFrom': ?allowedFrom,
    'allowedTo': ?allowedTo,
  };
}

final class Child {
  const Child({
    required this.id,
    required this.name,
    required this.pinHash,
    required this.limits,
    this.archived = false,
  });

  /// [id] is the Firestore document id, not part of the document itself.
  factory Child.fromJson(String id, Map<String, Object?> json) => Child(
    id: id,
    name: json['name']! as String,
    pinHash: json['pinHash']! as String,
    limits: Limits.fromJson(json['limits']! as Map<String, Object?>),
    archived: json['archived'] as bool? ?? false,
  );

  final String id;
  final String name;

  /// `pbkdf2-sha256$iterations$salt$hash`, see `pin.dart`.
  final String pinHash;
  final Limits limits;
  final bool archived;

  Map<String, Object?> toJson() => {
    'name': name,
    'pinHash': pinHash,
    'limits': limits.toJson(),
    'archived': archived,
  };
}

/// How to recognize a controlled game. Every non-empty criterion must match;
/// a rule without criteria never matches.
final class AppRule {
  const AppRule({
    required this.id,
    required this.name,
    this.exePath,
    this.exeName,
    this.commandLineContains,
    this.archived = false,
  });

  factory AppRule.fromJson(String id, Map<String, Object?> json) {
    final match = json['match']! as Map<String, Object?>;
    return AppRule(
      id: id,
      name: json['name']! as String,
      exePath: match['exePath'] as String?,
      exeName: match['exeName'] as String?,
      commandLineContains: match['commandLineContains'] as String?,
      archived: json['archived'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String? exePath;
  final String? exeName;
  final String? commandLineContains;
  final bool archived;

  Map<String, Object?> toJson() => {
    'name': name,
    'match': {
      'exePath': ?exePath,
      'exeName': ?exeName,
      'commandLineContains': ?commandLineContains,
    },
    'archived': archived,
  };
}

/// A running process as seen by the Windows service.
final class ProcessInfo {
  const ProcessInfo({
    required this.pid,
    required this.exePath,
    this.commandLine = '',
  });

  final int pid;
  final String exePath;
  final String commandLine;
}
