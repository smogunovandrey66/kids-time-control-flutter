import 'package:ktc_core/ktc_core.dart';

/// Which programs the users of the PC run and for how long, so the parent can
/// pick games from a list instead of looking up exe paths.
///
/// Only programs in user sessions count (not services), and not Windows'
/// own programs. Kept for [keepDays], at most [maxPrograms] reported.
final class ProgramCatalog {
  ProgramCatalog({
    this.keepDays = 14,
    this.maxPrograms = 40,
    this.ignoredFolders = const [r'C:\Windows'],
    this.ignoredNames = const {'ktc_agent.exe', 'ktc.exe'},
  });

  final int keepDays;
  final int maxPrograms;
  final List<String> ignoredFolders;
  final Set<String> ignoredNames;

  /// By lower-case path.
  final _entries = <String, _Entry>{};

  /// Called every tick with the running processes.
  void observe(List<ProcessInfo> processes, Duration elapsed, String today) {
    final counted = elapsed <= UsageTracker.maxTickGap
        ? elapsed
        : Duration.zero;
    final seen = <String>{};
    for (final process in processes) {
      if (process.sessionId == 0 || !_interesting(process.exePath)) continue;
      final key = process.exePath.toLowerCase();
      if (!seen.add(key)) continue; // several processes of one program
      final entry = _entries[key];
      if (entry == null) {
        _entries[key] = _Entry(process.exePath, counted.inMilliseconds, today);
      } else {
        entry
          ..milliseconds += counted.inMilliseconds
          ..lastSeen = today;
      }
    }
  }

  bool _interesting(String path) {
    final name = path.substring(path.lastIndexOf(r'\') + 1).toLowerCase();
    if (ignoredNames.contains(name)) return false;
    return !ignoredFolders.any((folder) => AppMatcher.isInFolder(path, folder));
  }

  /// The most used programs, dropping those not seen for [keepDays] before [today].
  List<SeenProgram> top(String today) {
    final cutoff = dateKey(
      DateTime.parse(today).subtract(Duration(days: keepDays)),
    );
    _entries.removeWhere((_, entry) => entry.lastSeen.compareTo(cutoff) < 0);
    final list = _entries.values.toList()
      ..sort((a, b) => b.milliseconds.compareTo(a.milliseconds));
    return [
      for (final entry in list.take(maxPrograms))
        SeenProgram(
          exePath: entry.path,
          seconds: entry.milliseconds ~/ 1000,
          lastSeen: entry.lastSeen,
        ),
    ];
  }

  /// For `programs.json`, so a restart does not lose the history.
  List<Object?> toJson(String today) => [
    for (final program in top(today)) program.toJson(),
  ];

  void load(List<Object?> json) {
    for (final item in json) {
      final program = SeenProgram.fromJson(item! as Map<String, Object?>);
      _entries[program.exePath.toLowerCase()] = _Entry(
        program.exePath,
        program.seconds * 1000,
        program.lastSeen,
      );
    }
  }
}

final class _Entry {
  _Entry(this.path, this.milliseconds, this.lastSeen);

  final String path;
  int milliseconds;
  String lastSeen;
}
