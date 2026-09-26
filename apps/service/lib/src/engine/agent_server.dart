import 'dart:async';
import 'dart:io';

import 'package:ktc_core/ktc_core.dart';

import 'login_broker.dart';

/// [LoginBroker] over the tray agents (`apps/agent`), one per Windows session.
///
/// Questions and notifications go to the agent in the active console session
/// (the one at the screen), or to the most recent agent if none is there.
/// Without an agent, a login waits [agentWait] for one to connect (the agent
/// starts a bit after Windows logon), then fails and the games are closed.
final class AgentServer implements LoginBroker {
  AgentServer({
    required int Function() activeSessionId,
    this.answerTimeout = const Duration(minutes: 2),
    this.agentWait = const Duration(seconds: 30),
    void Function()? onLogout,
    void Function(String message)? log,
  }) : _activeSessionId = activeSessionId,
       _onLogout = onLogout ?? (() {}),
       _log = log ?? ((_) {});

  final int Function() _activeSessionId;
  final void Function() _onLogout;
  final void Function(String message) _log;

  /// How long the child has to answer "Who is playing?".
  final Duration answerTimeout;
  final Duration agentWait;

  ServerSocket? _server;
  final _agents = <_Agent>[];
  final _agentConnected = StreamController<void>.broadcast();
  final _pending = <int, Completer<LoginReply?>>{};
  var _nextId = 1;
  AgentStatus _status = const AgentStatus();

  int get port => _server!.port;

  int get agentCount =>
      _agents.where((agent) => agent.sessionId != null).length;

  /// Listens on loopback only: the agent is on the same PC.
  Future<void> start({int port = agentPort}) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_accept);
  }

  Future<void> close() async {
    await _server?.close();
    for (final agent in List.of(_agents)) {
      agent.socket.destroy();
    }
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.complete(null);
    }
    await _agentConnected.close();
  }

  void _accept(Socket socket) {
    final agent = _Agent(socket);
    _agents.add(agent);
    decodeAgentMessages(socket).listen(
      (message) => _handle(agent, message),
      onError: (Object _) => _drop(agent),
      onDone: () => _drop(agent),
      cancelOnError: true,
    );
  }

  void _handle(_Agent agent, AgentMessage message) {
    switch (message) {
      case AgentHello(:final sessionId, :final version, :final userIsAdmin):
        final first = agent.sessionId == null;
        agent
          ..sessionId = sessionId
          ..userIsAdmin = userIsAdmin;
        if (!first) return;
        _log('Tray agent $version connected (Windows session $sessionId).');
        agent.send(_status);
        _agentConnected.add(null);
      case LoginReply(:final id):
        if (agent.sessionId == null) return;
        _pending.remove(id)?.complete(message);
      case LogoutRequest():
        if (agent.sessionId == null) return;
        _onLogout();
      case LoginRequest() || Notice() || AgentStatus():
        break; // service → agent only
    }
  }

  void _drop(_Agent agent) {
    if (!_agents.remove(agent)) return;
    agent.socket.destroy();
    if (agent.sessionId != null) {
      _log('Tray agent disconnected (Windows session ${agent.sessionId}).');
    }
    // Questions asked through this agent will not be answered.
    for (final id in agent.questions) {
      final pending = _pending.remove(id);
      if (pending != null && !pending.isCompleted) pending.complete(null);
    }
  }

  /// Whether the Windows user at the screen is an administrator, as told by
  /// their agent; `null` without an agent.
  bool? get activeUserIsAdmin => _target()?.userIsAdmin;

  _Agent? _target() {
    final ready = [
      for (final agent in _agents)
        if (agent.sessionId != null) agent,
    ];
    if (ready.isEmpty) return null;
    final active = _activeSessionId();
    return ready.lastWhere(
      (agent) => agent.sessionId == active,
      orElse: () => ready.last,
    );
  }

  @override
  Future<LoginAnswer?> askLogin({
    required List<({String id, String name, int? remainingSeconds})> children,
    required String appName,
    LoginError? previousError,
  }) async {
    var agent = _target();
    if (agent == null) {
      _log('Waiting for the tray agent to ask who is playing $appName...');
      try {
        await _agentConnected.stream.first.timeout(agentWait);
      } on Object {
        // timed out or closed
      }
      agent = _target();
      if (agent == null) {
        _log('No tray agent: nobody can log in to play $appName.');
        return null;
      }
    }

    final id = _nextId++;
    final completer = Completer<LoginReply?>();
    _pending[id] = completer;
    agent.questions.add(id);
    agent.send(
      LoginRequest(
        id: id,
        appName: appName,
        children: children,
        error: previousError,
      ),
    );

    final reply = await completer.future.timeout(
      answerTimeout,
      onTimeout: () {
        _pending.remove(id);
        _log('Nobody answered who is playing $appName.');
        return null;
      },
    );
    agent.questions.remove(id);
    if (reply == null || reply.cancelled) return null;
    return (childId: reply.childId!, pin: reply.pin!);
  }

  @override
  void notify(Notice notice) {
    _log('Notification: $notice');
    _target()?.send(notice);
  }

  /// Who is playing and how long is left, for the tray icon. Sent to every
  /// agent when it changes (callers round [remaining] to what they show).
  void publishStatus(String? childName, Duration? remaining) {
    final status = AgentStatus(
      childName: childName,
      remainingSeconds: remaining?.inSeconds,
    );
    if (status == _status) return;
    _status = status;
    for (final agent in _agents) {
      if (agent.sessionId != null) agent.send(status);
    }
  }
}

final class _Agent {
  _Agent(this.socket);

  final Socket socket;
  int? sessionId;
  bool userIsAdmin = false;
  final questions = <int>{};

  void send(AgentMessage message) {
    try {
      socket.add(encodeAgentMessage(message));
    } on Object {
      // The agent is gone; its socket's onDone cleans up.
    }
  }
}
