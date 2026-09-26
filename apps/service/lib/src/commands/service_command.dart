import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import '../cloud/cloud_sync.dart';
import '../cloud/firebase_rest.dart';
import '../engine/agent_server.dart';
import '../engine/console_login_broker.dart';
import '../engine/login_broker.dart';
import '../engine/program_catalog.dart';
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
    argParser.addOption(
      'agent-port',
      help: 'Port for the tray agents on 127.0.0.1.',
      defaultsTo: '$agentPort',
      hide: true,
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

    final catalog = ProgramCatalog();
    if (dir.readJson(dir.programsFile)?['programs']
        case final List<Object?> list) {
      try {
        catalog.load(list);
      } on Object catch (error) {
        _log('Ignoring a damaged programs.json: $error');
      }
    }

    late final ServiceEngine engine;
    AgentServer? agents;
    LoginBroker broker;
    if (results.flag('console')) {
      broker = ConsoleLoginBroker(
        out: _context.out,
        readLine: _context.readLine,
      );
    } else {
      final server = AgentServer(
        activeSessionId: _context.sessionState.activeSessionId,
        onLogout: () => engine.logout(),
        log: _log,
      );
      try {
        await server.start(port: int.parse(results.option('agent-port')!));
        agents = broker = server;
        _log('Waiting for tray agents on 127.0.0.1:${server.port}.');
      } on SocketException catch (error) {
        _log('Cannot listen for tray agents ($error): games will be closed.');
        broker = NoAgentBroker(_log);
      }
    }
    engine = ServiceEngine(
      processes: _context.processes(),
      broker: broker,
      dir: dir,
      wallClock: _context.wallClock,
      monotonicNow: _context.monotonicNow,
      config: configJson == null
          ? const LocalConfig(children: [], apps: [])
          : LocalConfig.fromJson(configJson),
      screenLocked: _context.sessionState.isLocked,
      catalog: catalog,
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
      afterTick: () => agents?.publishStatus(
        engine.activeChildName,
        _roundUpToMinutes(engine.remaining),
      ),
      catalog: catalog,
      userIsAdmin: () => agents?.activeUserIsAdmin,
      log: _log,
    );
    unawaited(_context.stopRequested?.then((_) => runner.stop()));
    await runner.run();
    cloud?.client.close();
    await agents?.close();
    return 0;
  }

  /// The tray shows whole minutes; sending seconds would mean a message per tick.
  static Duration? _roundUpToMinutes(Duration? remaining) => remaining == null
      ? null
      : Duration(minutes: (remaining.inSeconds + 59) ~/ 60);
}
