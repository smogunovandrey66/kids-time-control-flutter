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
    if (exePath == null && exeName == null && commandLine == null) return false;

    return (exePath == null || _equalsIgnoreCase(exePath, process.exePath)) &&
        (exeName == null ||
            _equalsIgnoreCase(exeName, _fileName(process.exePath))) &&
        (commandLine == null ||
            process.commandLine.toLowerCase().contains(
              commandLine.toLowerCase(),
            ));
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
