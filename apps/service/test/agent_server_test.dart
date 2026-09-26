import 'dart:async';
import 'dart:io';

import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

/// A tray agent for tests: a real socket to the server.
final class TestAgent {
  TestAgent._(this._socket) {
    decodeAgentMessages(_socket).listen(_messages.add);
  }

  static Future<TestAgent> connect(AgentServer server, int sessionId) async {
    final agent = TestAgent._(
      await Socket.connect(InternetAddress.loopbackIPv4, server.port),
    )..send(AgentHello(sessionId: sessionId, version: 'test'));
    return agent;
  }

  final Socket _socket;
  final _messages = StreamController<AgentMessage>.broadcast();

  Future<T> next<T extends AgentMessage>() =>
      _messages.stream.where((message) => message is T).cast<T>().first;

  void send(AgentMessage message) => _socket.add(encodeAgentMessage(message));

  Future<void> close() => _socket.close();
}

void main() {
  late AgentServer server;
  var activeSession = 1;
  var logouts = 0;
  final children = [
    const Child(
      id: 'ivan',
      name: 'Иван',
      pinHash: 'x',
      limits: Limits(weekdaySeconds: 60, weekendSeconds: 60),
    ),
  ];

  setUp(() async {
    activeSession = 1;
    logouts = 0;
    server = AgentServer(
      activeSessionId: () => activeSession,
      agentWait: const Duration(milliseconds: 300),
      answerTimeout: const Duration(seconds: 2),
      onLogout: () => logouts++,
    );
    await server.start(port: 0);
  });

  tearDown(() => server.close());

  Future<void> connected(int count) async {
    while (server.agentCount < count) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('asks the agent and returns what the child entered', () async {
    final agent = await TestAgent.connect(server, 1);
    await connected(1);

    final answer = server.askLogin(
      children: children,
      appName: 'Minecraft',
      previousError: LoginError.wrongPin,
    );
    final request = await agent.next<LoginRequest>();
    expect(request.appName, 'Minecraft');
    expect(request.children.single, (id: 'ivan', name: 'Иван'));
    expect(request.error, LoginError.wrongPin);

    agent.send(LoginReply(id: request.id, childId: 'ivan', pin: '1234'));
    expect(await answer, (childId: 'ivan', pin: '1234'));
    await agent.close();
  });

  test('cancel in the agent is a cancelled login', () async {
    final agent = await TestAgent.connect(server, 1);
    await connected(1);
    final answer = server.askLogin(children: children, appName: 'Roblox');
    agent.send(LoginReply.cancel((await agent.next<LoginRequest>()).id));
    expect(await answer, isNull);
    await agent.close();
  });

  test('asks the agent in the session at the screen', () async {
    final first = await TestAgent.connect(server, 1);
    final second = await TestAgent.connect(server, 2);
    await connected(2);

    unawaited(server.askLogin(children: children, appName: 'Minecraft'));
    final request = await first.next<LoginRequest>();
    first.send(LoginReply.cancel(request.id));

    activeSession = 2;
    server.notify(const Notice(kind: NoticeKind.timeUp, childName: 'Иван'));
    expect((await second.next<Notice>()).kind, NoticeKind.timeUp);
    await first.close();
    await second.close();
  });

  test('without an agent, waits a little and gives up', () async {
    expect(
      await server.askLogin(children: children, appName: 'Minecraft'),
      isNull,
    );
  });

  test('an agent connecting while the game waits gets the question', () async {
    final answer = server.askLogin(children: children, appName: 'Minecraft');
    final agent = await TestAgent.connect(server, 1);
    final request = await agent.next<LoginRequest>();
    agent.send(LoginReply(id: request.id, childId: 'ivan', pin: '1'));
    expect(await answer, isNotNull);
    await agent.close();
  });

  test('an agent that disconnects mid-question is a cancel', () async {
    final agent = await TestAgent.connect(server, 1);
    await connected(1);
    final answer = server.askLogin(children: children, appName: 'Minecraft');
    await agent.next<LoginRequest>();
    await agent.close();
    expect(await answer, isNull);
  });

  test('status goes to agents when it changes; logout comes back', () async {
    final agent = await TestAgent.connect(server, 1);
    expect(await agent.next<AgentStatus>(), const AgentStatus());

    server.publishStatus('Иван', const Duration(minutes: 25));
    expect(
      await agent.next<AgentStatus>(),
      const AgentStatus(childName: 'Иван', remainingSeconds: 1500),
    );

    agent.send(const LogoutRequest());
    while (logouts == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await agent.close();
  });

  test('a connection that never says hello is ignored', () async {
    final stranger = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    stranger.add(encodeAgentMessage(const LogoutRequest()));
    await stranger.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(logouts, 0);
    expect(server.agentCount, 0);
    await stranger.close();
  });
}
