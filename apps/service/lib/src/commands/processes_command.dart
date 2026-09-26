import 'package:args/command_runner.dart';

import 'cli.dart';

/// `ktc processes`: helps the parent find out how a game shows up in the process list.
final class ProcessesCommand extends Command<int> {
  ProcessesCommand(this._context) {
    argParser
      ..addFlag(
        'all',
        help: r'Include processes from C:\Windows.',
        negatable: false,
      )
      ..addOption(
        'filter',
        abbr: 'f',
        help: 'Show only paths or command lines containing this text.',
      );
  }

  final CliContext _context;

  @override
  String get name => 'processes';

  @override
  String get description =>
      'List running processes: id, executable path and command line.';

  @override
  int run() {
    final results = argResults!;
    final all = results.flag('all');
    final filter = results.option('filter')?.toLowerCase();

    final processes =
        _context.processes().list().where((process) {
          final path = process.exePath.toLowerCase();
          if (!all && path.startsWith(r'c:\windows\')) return false;
          if (filter != null &&
              !path.contains(filter) &&
              !process.commandLine.toLowerCase().contains(filter)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => a.exePath.toLowerCase().compareTo(b.exePath.toLowerCase()),
        );

    for (final process in processes) {
      _context.out
        ..writeln('${process.pid}\t${process.exePath}')
        ..writeln('\t${process.commandLine}');
    }
    _context.out.writeln('${processes.length} process(es)');
    return 0;
  }
}
