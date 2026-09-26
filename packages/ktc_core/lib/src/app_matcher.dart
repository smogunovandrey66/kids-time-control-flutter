import 'models.dart';

/// Decides whether a process is one of the controlled games.
final class AppMatcher {
  AppMatcher(Iterable<AppRule> rules)
    : _rules = rules.where((rule) => !rule.archived).toList(growable: false);

  final List<AppRule> _rules;

  /// The first matching rule, or `null` if the process is not a controlled game.
  AppRule? match(ProcessInfo process) {
    for (final rule in _rules) {
      if (ruleMatches(rule, process)) return rule;
    }
    return null;
  }

  /// All comparisons are case-insensitive (Windows paths are).
  static bool ruleMatches(AppRule rule, ProcessInfo process) {
    final exePath = _nonEmpty(rule.exePath);
    final exeName = _nonEmpty(rule.exeName);
    final commandLine = _nonEmpty(rule.commandLineContains);
    final folder = _nonEmpty(rule.folder);
    if (exePath == null &&
        exeName == null &&
        commandLine == null &&
        folder == null) {
      return false;
    }

    return (exePath == null || _equalsIgnoreCase(exePath, process.exePath)) &&
        (exeName == null ||
            _equalsIgnoreCase(exeName, _fileName(process.exePath))) &&
        (commandLine == null ||
            process.commandLine.toLowerCase().contains(
              commandLine.toLowerCase(),
            )) &&
        (folder == null || isInFolder(process.exePath, folder));
  }

  /// Whether [path] is inside [folder] (at any depth). In [folder], `*` matches
  /// one folder name; `/` and `\` are the same.
  static bool isInFolder(String path, String folder) {
    final pattern = _segments(folder);
    final segments = _segments(path);
    if (pattern.isEmpty || segments.length <= pattern.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (!_segmentMatches(pattern[i], segments[i])) return false;
    }
    return true;
  }

  static List<String> _segments(String path) => [
    for (final part in path.toLowerCase().split(RegExp(r'[\\/]+')))
      if (part.isNotEmpty) part,
  ];

  static bool _segmentMatches(String pattern, String segment) {
    if (!pattern.contains('*')) return pattern == segment;
    final regex = pattern.split('*').map(RegExp.escape).join('.*');
    return RegExp('^$regex\$').hasMatch(segment);
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static bool _equalsIgnoreCase(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  static String _fileName(String path) {
    final index = path.lastIndexOf(RegExp(r'[\\/]'));
    return index < 0 ? path : path.substring(index + 1);
  }
}
