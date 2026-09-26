import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import 'cli.dart';

/// `ktc match`: shows which running processes the rules in config.json treat as games.
final class MatchCommand extends Command<int> {
  MatchCommand(this._context) {
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'Path to config.json.',
      mandatory: true,
    );
  }

  final CliContext _context;

  @override
  String get name => 'match';

  @override
  String get description =>
      'Show running processes recognized as controlled games.';

  @override
  int run() {
    final config = LocalConfig.parse(
      _context.readFile(argResults!.option('config')!),
    );
    final matcher = AppMatcher(config.apps);

    var found = 0;
    for (final process in _context.processes().list()) {
      final app = matcher.match(process);
      if (app == null) continue;
      found++;
      _context.out.writeln(
        '${app.id} (${app.name})\t${process.pid}\t${process.exePath}',
      );
    }
    _context.out.writeln(
      found == 0
          ? 'No controlled games are running.'
          : '$found game process(es)',
    );
    return 0;
  }
}
