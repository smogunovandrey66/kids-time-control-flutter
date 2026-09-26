import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktc_agent/src/agent_app.dart';
import 'package:ktc_agent/src/agent_controller.dart';
import 'package:ktc_agent/src/strings.dart';
import 'package:ktc_core/ktc_core.dart';

/// The service side of one connection.
final class FakeService {
  final toAgent = StreamController<AgentMessage>();
  final fromAgent = <AgentMessage>[];
  var closed = false;

  AgentChannel get channel => (
    messages: toAgent.stream,
    send: fromAgent.add,
    close: () => closed = true,
  );
}

void main() {
  late List<FakeService> connections;
  late bool serviceUp;
  late AgentController controller;

  const strings = RussianStrings();
  const prompt = LoginRequest(
    id: 1,
    appName: 'Minecraft',
    children: [
      (id: 'ivan', name: 'Иван', remainingSeconds: 600),
      (id: 'marina', name: 'Марина', remainingSeconds: 0),
    ],
  );

  setUp(() {
    connections = [];
    serviceUp = true;
    controller = AgentController(
      sessionId: 3,
      userIsAdmin: true,
      version: 'test',
      connect: () async {
        if (!serviceUp) throw Exception('connection refused');
        final service = FakeService();
        connections.add(service);
        return service.channel;
      },
    );
  });

  Future<FakeService> start(WidgetTester tester) async {
    await tester.pumpWidget(AgentApp(controller: controller, strings: strings));
    controller.start();
    await tester.pump();
    return connections.last;
  }

  Future<void> say(
    WidgetTester tester,
    FakeService service,
    AgentMessage m,
  ) async {
    service.toAgent.add(m);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('says hello and shows who is playing', (tester) async {
    final service = await start(tester);
    expect(service.fromAgent.single, isA<AgentHello>());
    final hello = service.fromAgent.single as AgentHello;
    expect((hello.sessionId, hello.userIsAdmin), (3, true));
    expect(find.text('Никто не играет'), findsOneWidget);

    await say(
      tester,
      service,
      const AgentStatus(childName: 'Иван', remainingSeconds: 22 * 60),
    );
    expect(find.text('Играет Иван, осталось 22 минуты'), findsOneWidget);
  });

  testWidgets('the child picks a name, types the PIN and plays', (
    tester,
  ) async {
    final service = await start(tester);
    await say(tester, service, prompt);
    expect(find.text('Кто играет в Minecraft?'), findsOneWidget);

    final play = find.widgetWithText(FilledButton, 'Играть');
    expect(tester.widget<FilledButton>(play).onPressed, isNull);

    await tester.tap(find.text('Марина'));
    await tester.enterText(find.byType(TextField), '12ab34');
    await tester.pump();
    await tester.tap(play);
    await tester.pump();

    final reply = service.fromAgent.last as LoginReply;
    expect((reply.id, reply.childId, reply.pin), (1, 'marina', '1234'));
    expect(controller.prompt, isNull);
    expect(find.text('Кто играет в Minecraft?'), findsNothing);
  });

  testWidgets('a single child is preselected; Enter submits', (tester) async {
    final service = await start(tester);
    await say(
      tester,
      service,
      const LoginRequest(
        id: 2,
        appName: 'Roblox',
        children: [(id: 'ivan', name: 'Иван', remainingSeconds: null)],
        error: LoginError.wrongPin,
      ),
    );
    expect(find.text('Неверный PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final reply = service.fromAgent.last as LoginReply;
    expect((reply.childId, reply.pin), ('ivan', '1234'));
  });

  testWidgets('cancel', (tester) async {
    final service = await start(tester);
    await say(tester, service, prompt);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    expect((service.fromAgent.last as LoginReply).cancelled, isTrue);
  });

  testWidgets('notifications show and hide by themselves', (tester) async {
    final service = await start(tester);
    await say(
      tester,
      service,
      const Notice(kind: NoticeKind.minutesLeft, childName: 'Иван', minutes: 5),
    );
    expect(find.text('Иван, осталось 5 минут'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Иван, осталось 5 минут'), findsNothing);
  });

  testWidgets('reconnects when the service restarts', (tester) async {
    final first = await start(tester);
    await say(tester, first, prompt);

    serviceUp = false;
    await first.toAgent.close();
    await tester.pump();
    expect(controller.connected, isFalse);
    expect(controller.prompt, isNull, reason: 'the question is gone');
    expect(find.text('Нет связи со службой контроля'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3)); // refused, retries later
    expect(connections, hasLength(1));

    serviceUp = true;
    await tester.pump(const Duration(seconds: 3));
    expect(connections, hasLength(2));
    expect(connections.last.fromAgent.single, isA<AgentHello>());
    expect(controller.connected, isTrue);
  });

  testWidgets('log out goes to the service', (tester) async {
    final service = await start(tester);
    controller.logout();
    expect(service.fromAgent.last, isA<LogoutRequest>());
  });

  test('Russian plural forms of minutes', () {
    expect([1, 2, 5, 11, 12, 21, 22, 25, 101, 111].map(strings.minutes), [
      '1 минута',
      '2 минуты',
      '5 минут',
      '11 минут',
      '12 минут',
      '21 минута',
      '22 минуты',
      '25 минут',
      '101 минута',
      '111 минут',
    ]);
    expect(Strings.forLocale('ru_RU'), isA<RussianStrings>());
    expect(Strings.forLocale('en_US'), isA<EnglishStrings>());
  });
}
