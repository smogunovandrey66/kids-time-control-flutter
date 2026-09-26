import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import '../cloud/cloud_sync.dart';
import '../cloud/firebase_rest.dart';
import '../engine/console_login_broker.dart';
import '../engine/login_broker.dart';
import '../engine/service_engine.dart';
import '../engine/service_runner.dart';
import '../storage/data_dir.dart';
import 'cli.dart';
import 'cloud_options.dart';

/// `ktc service`: the Windows service main loop (started by WinSW).
final class ServiceCommand extends Command<int> {
  ServiceCommand(this._context) {
    addDataDirOption(argParser);
    addEmulatorFlag(argParser);
    argParser.addFlag(
      'console',
      help:
          'Ask who is playing in this console (testing without the tray agent).',
      negatable: false,
    );
  }

  final CliContext _context;

  @override
  String get name => 'service';

  @override
  String get description =>
      'Run the service loop (normally started by the Windows service).';

  void _log(String message) => _context.out.writeln(
    '${_context.wallClock().toIso8601String()} $message',
  );

  @override
  Future<int> run() async {
    final results = argResults!;
    final dir = DataDir(results.option('data-dir')!);
    _log('Kids Time Control $appVersion, data: ${dir.path}');

    final configJson = dir.readJson(dir.configFile);
    if (configJson == null) {
      _log(
        'No config.json yet: run `ktc pair` and `ktc sync`, or create it by hand.',
      );
    }

    final LoginBroker broker = results.flag('console')
        ? ConsoleLoginBroker(out: _context.out, readLine: _context.readLine)
        : NoAgentBroker(_log);
    final engine = ServiceEngine(
      processes: _context.processes(),
      broker: broker,
      dir: dir,
      wallClock: _context.wallClock,
      monotonicNow: _context.monotonicNow,
      config: configJson == null
          ? const LocalConfig(children: [], apps: [])
          : LocalConfig.fromJson(configJson),
      log: _log,
    );

    CloudSync? cloud;
    if (dir.readJson(dir.cloudFile) case final json?) {
      final state = CloudState.fromJson(json);
      if (state.familyId != null) {
        cloud = CloudSync(
          FirebaseRestClient(
            endpointsFor(state, emulator: results.flag('emulator')),
            client: _context.httpClient(),
          ),
          state,
        );
      }
    }
    _log(
      cloud == null ? 'Cloud: not paired, working offline.' : 'Cloud: paired.',
    );

    final runner = ServiceRunner(
      engine: engine,
      dir: dir,
      cloud: cloud,
      sleep: _context.sleep,
      monotonicNow: _context.monotonicNow,
      wallClock: _context.wallClock,
      log: _log,
    );
    unawaited(_context.stopRequested?.then((_) => runner.stop()));
    await runner.run();
    cloud?.client.close();
    return 0;
  }
}
