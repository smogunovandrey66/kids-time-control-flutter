import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../platform/process_control.dart';
import '../platform/windows_process_control.dart';
import 'hash_pin_command.dart';
import 'match_command.dart';
import 'processes_command.dart';
import 'run_command.dart';

/// Everything the commands need from the outside world; tests pass fakes.
final class CliContext {
  CliContext({
    required this.out,
    required this.processes,
    required this.readLine,
    this.readFile = _readFile,
    this.sleep = _sleep,
    Duration Function()? monotonicNow,
    this.stopRequested,
  }) : monotonicNow = monotonicNow ?? _monotonicClock;

  /// Real environment: stdout, stdin and WinAPI (on Windows only).
  factory CliContext.system() => CliContext(
    out: stdout,
    processes: () {
      if (!Platform.isWindows) {
        throw UsageException('This command works on Windows only.', '');
      }
      return WindowsProcessControl();
    },
    readLine: () => stdin.readLineSync(),
    stopRequested: ProcessSignal.sigint.watch().first,
  );

  final StringSink out;
  final ProcessControl Function() processes;
  final String? Function() readLine;
  final String Function(String path) readFile;
  final Future<void> Function(Duration duration) sleep;

  /// Monotonic time (not affected by changes of the system clock).
  final Duration Function() monotonicNow;

  /// Completes when the user presses Ctrl+C; `null` means "run until time is up".
  final Future<void>? stopRequested;

  static String _readFile(String path) => File(path).readAsStringSync();

  static Future<void> _sleep(Duration duration) =>
      Future<void>.delayed(duration);

  static final Stopwatch _stopwatch = Stopwatch()..start();

  static Duration _monotonicClock() => _stopwatch.elapsed;
}

CommandRunner<int> buildCli(CliContext context) =>
    CommandRunner<int>('ktc', 'Kids Time Control: tools for the Windows PC.')
      ..addCommand(ProcessesCommand(context))
      ..addCommand(MatchCommand(context))
      ..addCommand(HashPinCommand(context))
      ..addCommand(RunCommand(context));
