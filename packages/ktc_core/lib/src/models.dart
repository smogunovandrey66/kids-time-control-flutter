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
    this.bonus,
    this.archived = false,
  });

  /// [id] is the Firestore document id, not part of the document itself.
  factory Child.fromJson(String id, Map<String, Object?> json) => Child(
    id: id,
    name: json['name']! as String,
    pinHash: json['pinHash']! as String,
    limits: Limits.fromJson(json['limits']! as Map<String, Object?>),
    bonus: switch (json['bonus']) {
      final Map<String, Object?> bonus => Bonus.fromJson(bonus),
      _ => null,
    },
    archived: json['archived'] as bool? ?? false,
  );

  final String id;
  final String name;

  /// `pbkdf2-sha256$iterations$salt$hash`, see `pin.dart`.
  final String pinHash;
  final Limits limits;

  /// Extra time granted by the parent for one day.
  final Bonus? bonus;
  final bool archived;

  /// Today's limit including the parent's bonus.
  Duration limitFor(DateTime date) {
    final extra = bonus != null && bonus!.date == dateKey(date)
        ? bonus!.seconds
        : 0;
    return Duration(seconds: limits.secondsFor(date) + extra);
  }

  Child copyWith({
    String? name,
    String? pinHash,
    Limits? limits,
    Bonus? bonus,
    bool? archived,
  }) => Child(
    id: id,
    name: name ?? this.name,
    pinHash: pinHash ?? this.pinHash,
    limits: limits ?? this.limits,
    bonus: bonus ?? this.bonus,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'pinHash': pinHash,
    'limits': limits.toJson(),
    'bonus': ?bonus?.toJson(),
    'archived': archived,
  };
}

/// Extra time for one local day.
final class Bonus {
  const Bonus({required this.date, required this.seconds});

  factory Bonus.fromJson(Map<String, Object?> json) =>
      Bonus(date: json['date']! as String, seconds: json['seconds']! as int);

  /// `YYYY-MM-DD`, see [dateKey].
  final String date;
  final int seconds;

  Map<String, Object?> toJson() => {'date': date, 'seconds': seconds};
}

/// Local calendar day as used in document ids: `YYYY-MM-DD`.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// How to recognize a controlled game. Every non-empty criterion must match;
/// a rule without criteria never matches.
final class AppRule {
  const AppRule({
    required this.id,
    required this.name,
    this.exePath,
    this.exeName,
    this.commandLineContains,
    this.folder,
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
      folder: match['folder'] as String?,
      archived: json['archived'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String? exePath;
  final String? exeName;
  final String? commandLineContains;

  /// Any program inside this folder or its subfolders. `*` stands for one
  /// folder name, e.g. `C:\Users\*\AppData\Local\Roblox` for every user.
  /// Renaming or copying the game's exe inside the folder does not help.
  final String? folder;
  final bool archived;

  Map<String, Object?> toJson() => {
    'name': name,
    'match': {
      'exePath': ?exePath,
      'exeName': ?exeName,
      'commandLineContains': ?commandLineContains,
      'folder': ?folder,
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
