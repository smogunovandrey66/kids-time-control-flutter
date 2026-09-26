import 'package:ktc_core/ktc_core.dart';

/// A program seen on the family's PCs, as offered in "Pick from the PC".
final class ProgramCandidate {
  const ProgramCandidate({
    required this.program,
    required this.deviceNames,
    this.matchedBy,
  });

  /// Merged over all PCs: total time, latest day.
  final SeenProgram program;
  final List<String> deviceNames;

  /// The game rule that already covers it, if any.
  final AppRule? matchedBy;
}

/// Programs from all PCs, the same path merged, most used first; each marked
/// with the game rule that already matches it.
List<ProgramCandidate> programCandidates(
  List<Device> devices,
  List<AppRule> apps,
) {
  final merged = <String, ({SeenProgram program, List<String> devices})>{};
  for (final device in devices) {
    for (final program in device.programs) {
      final key = program.exePath.toLowerCase();
      final previous = merged[key];
      merged[key] = previous == null
          ? (program: program, devices: [device.name])
          : (
              program: SeenProgram(
                exePath: previous.program.exePath,
                seconds: previous.program.seconds + program.seconds,
                lastSeen:
                    program.lastSeen.compareTo(previous.program.lastSeen) > 0
                    ? program.lastSeen
                    : previous.program.lastSeen,
              ),
              devices: [...previous.devices, device.name],
            );
    }
  }

  final matcher = AppMatcher(apps);
  final candidates = [
    for (final entry in merged.values)
      ProgramCandidate(
        program: entry.program,
        deviceNames: entry.devices,
        matchedBy: matcher.match(
          ProcessInfo(pid: 0, exePath: entry.program.exePath),
        ),
      ),
  ]..sort((a, b) => b.program.seconds.compareTo(a.program.seconds));
  return candidates;
}
