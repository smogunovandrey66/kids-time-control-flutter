import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import '../game_monitor.dart';
import 'cli.dart';

/// `ktc run`: the service loop in a console window, for trying the rules and
/// the time accounting before installing the service.
///
/// Safe by default: games are only closed with `--enforce`.
final class RunCommand extends Command<int> {
  RunCommand(this._context) {
    argParser
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to config.json.',
        mandatory: true,
      )
      ..addOption('child', help: 'Child id from config.json.', mandatory: true)
      ..addOption('pin', help: 'PIN (asked interactively if omitted).')
      ..addOption(
        'limit-minutes',
        help: "Override today's limit (for testing).",
      )
      ..addOption('interval', help: 'Seconds between checks.', defaultsTo: '2')
      ..addFlag(
        'enforce',
        help: 'Really close games when time is up.',
        negatable: false,
      );
  }

  final CliContext _context;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Track the time of one child in the console (service logic without the service).';

  @override
  Future<int> run() async {
    final results = argResults!;
    final out = _context.out;
    final config = LocalConfig.parse(
      _context.readFile(results.option('config')!),
    );
    final child = config.child(results.option('child')!);
    if (child == null) {
      usageException('Unknown child "${results.option('child')}".');
    }

    final pin = results.option('pin') ?? _askPin(child);
    if (pin == null || !verifyPin(pin, child.pinHash)) {
      out.writeln('Wrong PIN.');
      return 1;
    }

    final limitMinutes = results.option('limit-minutes');
    final limit = limitMinutes != null
        ? Duration(minutes: int.parse(limitMinutes))
        : Duration(seconds: child.limits.secondsFor(DateTime.now()));
    final interval = Duration(seconds: int.parse(results.option('interval')!));
    final enforce = results.flag('enforce');

    final monitor = GameMonitor(
      processes: _context.processes(),
      matcher: AppMatcher(config.apps),
      tracker: UsageTracker(limit: limit),
    );

    out.writeln(
      '${child.name}: ${_format(monitor.tracker.remaining)} left. '
      '${enforce ? 'Games WILL be closed' : 'Dry run: games will not be closed'} when time is up. '
      'Ctrl+C to stop.',
    );

    var stop = false;
    unawaited(_context.stopRequested?.then((_) => stop = true));

    var last = _context.monotonicNow();
    var lastGames = <String>{};
    var lastReportedMinute = monitor.tracker.remaining.inMinutes;

    while (!stop) {
      await _context.sleep(interval);
      final now = _context.monotonicNow();
      final elapsed = now - last;
      last = now;

      final tick = monitor.tick(elapsed);
      final games = {for (final game in tick.games) game.app.name};
      if (games.difference(lastGames).isNotEmpty ||
          lastGames.difference(games).isNotEmpty) {
        out.writeln(
          games.isEmpty ? 'No games running.' : 'Playing: ${games.join(', ')}',
        );
        lastGames = games;
      }

      final remaining = monitor.tracker.remaining;
      if (tick.event != TrackerEvent.none &&
          tick.event != TrackerEvent.timeUp) {
        out.writeln('WARNING: ${_format(remaining)} left.');
      } else if (tick.games.isNotEmpty &&
          remaining.inMinutes < lastReportedMinute) {
        out.writeln('${_format(remaining)} left.');
      }
      lastReportedMinute = remaining.inMinutes;

      if (monitor.tracker.timeUp && tick.games.isNotEmpty) {
        if (enforce) {
          final closed = monitor.closeAll(tick.games);
          out.writeln('Time is up: closed ${closed.length} game process(es).');
        } else if (tick.event == TrackerEvent.timeUp) {
          out.writeln('Time is up. Dry run: would close ${games.join(', ')}.');
        }
      }

      if (_context.stopRequested == null &&
          monitor.tracker.timeUp &&
          tick.games.isEmpty) {
        break;
      }
    }

    out.writeln('Used: ${_format(monitor.tracker.used)}.');
    return 0;
  }

  String? _askPin(Child child) {
    _context.out.write('PIN for ${child.name}: ');
    return _context.readLine()?.trim();
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
