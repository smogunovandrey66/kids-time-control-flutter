import 'package:ktc_core/ktc_core.dart';

import 'platform/process_control.dart';

/// A running process recognized as a controlled game.
typedef RunningGame = ({ProcessInfo process, AppRule app});

/// Result of one monitoring step.
typedef MonitorTick = ({List<RunningGame> games, TrackerEvent event});

/// Joins the process list, game recognition and time accounting.
/// Pure logic over [ProcessControl], so it is tested with a fake.
final class GameMonitor {
  GameMonitor({
    required ProcessControl processes,
    required AppMatcher matcher,
    required this.tracker,
  }) : _processes = processes,
       _matcher = matcher;

  final ProcessControl _processes;
  final AppMatcher _matcher;
  final UsageTracker tracker;

  List<RunningGame> runningGames() => [
    for (final process in _processes.list())
      if (_matcher.match(process) case final app?) (process: process, app: app),
  ];

  /// Accounts [elapsed] if any game is running.
  MonitorTick tick(Duration elapsed) {
    final games = runningGames();
    final event = tracker.tick(elapsed, gameRunning: games.isNotEmpty);
    return (games: games, event: event);
  }

  /// Closes [games]; returns the ids of the processes that were terminated.
  List<int> closeAll(List<RunningGame> games) => [
    for (final game in games)
      if (_processes.terminate(game.process.pid)) game.process.pid,
  ];
}
