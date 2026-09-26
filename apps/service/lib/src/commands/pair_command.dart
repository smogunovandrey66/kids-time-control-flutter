import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import '../cloud/cloud_sync.dart';
import '../storage/data_dir.dart';
import 'cli.dart';
import 'cloud_options.dart';

/// `ktc pair`: connects this PC to a family. Shows a code for the parent's app
/// and waits until the parent enters it.
final class PairCommand extends Command<int> {
  PairCommand(this._context) {
    argParser
      ..addOption(
        'api-key',
        help: 'Firebase Web API key (Project settings → General).',
        mandatory: true,
      )
      ..addOption('project-id', help: 'Firebase project id.', mandatory: true)
      ..addOption(
        'name',
        help: 'Name of this PC shown to the parent.',
        defaultsTo: 'PC',
      )
      ..addOption(
        'timeout-minutes',
        help: 'How long to wait for the parent.',
        defaultsTo: '15',
      );
    addDataDirOption(argParser);
    addEmulatorFlag(argParser);
  }

  final CliContext _context;

  @override
  String get name => 'pair';

  @override
  String get description =>
      'Connect this PC to a family: shows a code for the parent app.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final out = _context.out;
    final dir = DataDir(results.option('data-dir')!);
    final state = CloudState(
      apiKey: results.option('api-key')!,
      projectId: results.option('project-id')!,
      deviceName: results.option('name')!,
    );
    // Keep the anonymous identity of this PC when pairing again with the same project.
    if (dir.readJson(dir.cloudFile) case final json?) {
      final previous = CloudState.fromJson(json);
      if (previous.projectId == state.projectId) {
        state
          ..uid = previous.uid
          ..refreshToken = previous.refreshToken;
      }
    }

    final sync = openSync(_context, state, results);
    try {
      final code = await sync.startPairing();
      dir.writeJson(dir.cloudFile, state.toJson());
      out
        ..writeln('Pairing code: ${PairingCode.format(code)}')
        ..writeln(
          'Enter it in the parent app: Computers → Pair computer. Waiting...',
        );

      final timeout = Duration(
        minutes: int.parse(results.option('timeout-minutes')!),
      );
      final started = _context.monotonicNow();
      while (_context.monotonicNow() - started < timeout) {
        await _context.sleep(const Duration(seconds: 3));
        final familyId = await sync.findFamily();
        if (familyId != null) {
          await sync.reportStatus(
            appVersion: appVersion,
            now: _context.wallClock(),
          );
          dir.writeJson(dir.cloudFile, state.toJson());
          out.writeln(
            'Paired. Now run `ktc sync` to download children and games.',
          );
          return 0;
        }
      }
      out.writeln('The code was not entered in time. Run `ktc pair` again.');
      return 1;
    } finally {
      sync.client.close();
    }
  }
}
