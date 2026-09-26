import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import 'cli.dart';
import 'cloud_options.dart';

/// `ktc sync`: downloads children and games into config.json and uploads usage.
final class SyncCommand extends Command<int> {
  SyncCommand(this._context) {
    addDataDirOption(argParser);
    addEmulatorFlag(argParser);
  }

  final CliContext _context;

  @override
  String get name => 'sync';

  @override
  String get description =>
      'Download children and games, upload usage of the last 7 days.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final out = _context.out;
    final (:dir, :state) = loadPairedState(results);
    final sync = openSync(_context, state, results);
    try {
      if (await sync.findFamily() == null) {
        out.writeln(
          'This PC was removed from the family. Run `ktc pair` to connect it again.',
        );
        dir.writeJson(dir.cloudFile, state.toJson());
        return 1;
      }

      final config = await sync.pullConfig();
      dir.writeJson(dir.configFile, config.toJson());

      final today = _context.wallClock();
      final week = {
        for (var day = 0; day < 7; day++)
          dateKey(today.subtract(Duration(days: day))),
      };
      final usage = dir.usageForDates(week);
      await sync.pushUsage(usage);
      await sync.reportStatus(appVersion: appVersion, now: today);
      dir.writeJson(dir.cloudFile, state.toJson());

      out.writeln(
        'Synced: ${config.children.length} child(ren), ${config.apps.length} game(s), '
        '${usage.length} usage record(s) uploaded.',
      );
      return 0;
    } finally {
      sync.client.close();
    }
  }
}
