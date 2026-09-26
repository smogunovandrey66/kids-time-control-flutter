import 'dart:async';

import 'package:ktc_core/ktc_core.dart';

import '../platform/process_control.dart';
import '../storage/data_dir.dart';
import 'login_broker.dart';

/// The heart of the Windows service: who is playing, how long, and what to close.
///
/// Called by the runner every couple of seconds with the elapsed monotonic time.
/// Pure logic over [ProcessControl], [LoginBroker] and [DataDir]; tested with fakes.
///
/// Lifecycle:
/// 1. A game starts and nobody is logged in: the game is suspended and the
///    broker asks who is playing. Right PIN and time left: games resume and a
///    session starts. Otherwise the games are closed.
/// 2. During a session time is accounted (once, however many games run),
///    usage is saved, warnings are shown; when time is up the games get
///    [closeGrace] and are then closed, and new ones are closed immediately.
///    Closing the games ends the session, so a brother or sister with time
///    left can log in right away.
/// 3. The session ends after [idleTimeout] without games, when the child
///    logs out in the tray agent, or when the screen is locked. While the
///    screen is locked nobody is asked to log in; games stay suspended.
final class ServiceEngine {
  ServiceEngine({
    required ProcessControl processes,
    required LoginBroker broker,
    required DataDir dir,
    required DateTime Function() wallClock,
    required Duration Function() monotonicNow,
    LocalConfig config = const LocalConfig(children: [], apps: []),
    this.idleTimeout = const Duration(minutes: 10),
    this.closeGrace = const Duration(seconds: 30),
    this.maxFailures = 5,
    this.lockout = const Duration(minutes: 5),
    bool Function()? screenLocked,
    void Function(String message)? log,
  }) : _processes = processes,
       _screenLocked = screenLocked ?? (() => false),
       _broker = broker,
       _dir = dir,
       _wallClock = wallClock,
       _monotonicNow = monotonicNow,
       _log = log ?? ((_) {}),
       _config = config,
       _matcher = AppMatcher(config.apps);

  final ProcessControl _processes;
  final LoginBroker _broker;
  final DataDir _dir;
  final DateTime Function() _wallClock;
  final Duration Function() _monotonicNow;
  final bool Function() _screenLocked;
  final void Function(String message) _log;

  final Duration idleTimeout;
  final Duration closeGrace;
  final int maxFailures;
  final Duration lockout;

  LocalConfig _config;
  AppMatcher _matcher;
  _Session? _session;
  final _suspended = <int>{};

  /// Processes asked to close: ignored while they shut down, handled again if
  /// still alive after [_closeTimeout].
  final _closing = <int, Duration>{};
  static const _closeTimeout = Duration(seconds: 10);
  Future<void>? _pendingLogin;
  final _failures = <String, ({int count, Duration lastAt})>{};

  /// Usage documents changed since the last [takeDirtyUsage] (for cloud upload).
  final _dirtyUsage = <String, DailyUsage>{};

  String? get activeChildId => _session?.child.id;

  String? get activeChildName => _session?.child.name;

  /// Time left for the logged-in child, `null` without a session.
  Duration? get remaining => _session?.tracker.remaining;

  bool get loginPending => _pendingLogin != null;

  LocalConfig get config => _config;

  /// New children and games (e.g. from the cloud). An active session picks up
  /// the child's new limit and bonus.
  void updateConfig(LocalConfig config) {
    _config = config;
    _matcher = AppMatcher(config.apps);
    final session = _session;
    if (session == null) return;
    final child = config.child(session.child.id);
    if (child == null) {
      _endSession('child removed');
    } else {
      session.child = child;
      session.tracker = _trackerFor(child, session.usage);
    }
  }

  List<DailyUsage> takeDirtyUsage() {
    final list = _dirtyUsage.values.toList();
    _dirtyUsage.clear();
    return list;
  }

  void tick(Duration elapsed) {
    final now = _monotonicNow();
    final running = [
      for (final process in _processes.list())
        if (_matcher.match(process) case final app?)
          (pid: process.pid, app: app),
    ];
    // Forget processes that are gone.
    final pids = {for (final game in running) game.pid};
    _suspended.retainAll(pids);
    _closing.removeWhere(
      (pid, since) => !pids.contains(pid) || now - since >= _closeTimeout,
    );
    final games = [
      for (final game in running)
        if (!_closing.containsKey(game.pid)) game,
    ];

    final locked = _screenLocked();
    if (locked && _session != null) _endSession('screen locked');

    final session = _session;
    if (session == null) {
      if (games.isEmpty) return;
      for (final game in games) {
        if (_suspended.add(game.pid) && _processes.suspend(game.pid)) {
          _log(
            'Suspended ${game.app.name} (pid ${game.pid}) until someone logs in.',
          );
        }
      }
      if (locked) return; // ask when someone is at the PC again
      _pendingLogin ??= _login(
        games.first.app.name,
      ).whenComplete(() => _pendingLogin = null);
      return;
    }

    _tickSession(session, elapsed, games);
  }

  void _tickSession(
    _Session session,
    Duration elapsed,
    List<({int pid, AppRule app})> games,
  ) {
    final now = _monotonicNow();

    // A new day starts with a new usage record and the new day's limit.
    final today = dateKey(_wallClock());
    if (today != session.usage.date) {
      session.usage = _dir.loadUsage(session.child.id, today);
      session.tracker = _trackerFor(session.child, session.usage);
    }

    final event = session.tracker.tick(elapsed, gameRunning: games.isNotEmpty);
    if (games.isNotEmpty && elapsed <= UsageTracker.maxTickGap) {
      session.carryMs += elapsed.inMilliseconds;
      final seconds = session.carryMs ~/ 1000;
      session.carryMs -= seconds * 1000;
      if (seconds > 0) {
        session.usage = accumulateUsage(
          session.usage,
          seconds,
          runningAppIds: {for (final game in games) game.app.id},
        );
        _dir.saveUsage(session.usage);
        _dirtyUsage[DailyUsage.documentId(
              session.usage.childId,
              session.usage.date,
            )] =
            session.usage;
      }
    }

    switch (event) {
      case TrackerEvent.warning10Min ||
          TrackerEvent.warning5Min ||
          TrackerEvent.warning1Min:
        _broker.notify(
          Notice(
            kind: NoticeKind.minutesLeft,
            childName: session.child.name,
            minutes: session.tracker.remaining.inMinutes + 1,
          ),
        );
      case TrackerEvent.timeUp:
        _broker.notify(
          Notice(kind: NoticeKind.timeUp, childName: session.child.name),
        );
      case TrackerEvent.none:
        break;
    }

    if (!session.tracker.timeUp) {
      session.timeUpAt = null; // e.g. extra time from the parent
    } else if (games.isNotEmpty) {
      session.timeUpAt ??= now;
      if (now - session.timeUpAt! >= closeGrace) {
        for (final game in games) {
          _close(game.pid);
          _log(
            'Time is up for ${session.child.name}: closed ${game.app.name}.',
          );
        }
        _endSession('time is up');
        return;
      }
    }

    if (games.isEmpty) {
      session.idleSince ??= now;
      if (now - session.idleSince! >= idleTimeout) {
        _endSession('no games for a while');
      }
    } else {
      session.idleSince = null;
    }
  }

  Future<void> _login(String appName) async {
    LoginError? error;
    for (var attempt = 0; attempt < 3; attempt++) {
      final children = [
        for (final child in _config.children)
          if (!child.archived) child,
      ];
      final answer = await _broker.askLogin(
        children: children,
        appName: appName,
        previousError: error,
      );
      if (answer == null) break;

      final child = _config.child(answer.childId);
      if (child == null) break;
      if (_isLocked(child.id)) {
        error = LoginError.locked;
        continue;
      }
      if (!verifyPin(answer.pin, child.pinHash)) {
        _recordFailure(child.id);
        error = _isLocked(child.id) ? LoginError.locked : LoginError.wrongPin;
        _log('Wrong PIN for ${child.name}.');
        continue;
      }
      _failures.remove(child.id);

      final usage = _dir.loadUsage(child.id, dateKey(_wallClock()));
      final tracker = _trackerFor(child, usage);
      if (tracker.timeUp) {
        error = LoginError.noTimeLeft;
        _broker.notify(
          Notice(kind: NoticeKind.noTimeLeft, childName: child.name),
        );
        break;
      }

      _session = _Session(child: child, usage: usage, tracker: tracker);
      _log('${child.name} logged in, ${tracker.remaining.inMinutes} min left.');
      for (final pid in _suspended) {
        _processes.resume(pid);
      }
      _suspended.clear();
      return;
    }

    for (final pid in _suspended) {
      _close(pid);
    }
    if (_suspended.isNotEmpty) {
      _log('Closed ${_suspended.length} game process(es): no login.');
    }
    _suspended.clear();
  }

  void _close(int pid) {
    _closing[pid] = _monotonicNow();
    _processes.terminate(pid);
  }

  /// Ends the current session (logout, screen lock, idle timeout).
  void logout() => _endSession('logout');

  void _endSession(String reason) {
    final session = _session;
    if (session == null) return;
    _log('${session.child.name} logged out ($reason).');
    _session = null;
  }

  UsageTracker _trackerFor(Child child, DailyUsage usage) => UsageTracker(
    limit: child.limitFor(_wallClock()),
    used: Duration(seconds: usage.totalSeconds),
  );

  bool _isLocked(String childId) {
    final failures = _failures[childId];
    if (failures == null || failures.count < maxFailures) return false;
    if (_monotonicNow() - failures.lastAt >= lockout) {
      _failures.remove(childId);
      return false;
    }
    return true;
  }

  void _recordFailure(String childId) {
    final previous = _failures[childId];
    _failures[childId] = (
      count: (previous?.count ?? 0) + 1,
      lastAt: _monotonicNow(),
    );
  }
}

final class _Session {
  _Session({required this.child, required this.usage, required this.tracker});

  Child child;
  DailyUsage usage;
  UsageTracker tracker;
  int carryMs = 0;
  Duration? idleSince;
  Duration? timeUpAt;
}
