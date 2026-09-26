import 'dart:async';
import 'dart:convert';

import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  Future<List<AgentMessage>> decode(List<List<int>> chunks) =>
      decodeAgentMessages(Stream.fromIterable(chunks)).toList();

  test('every message survives encoding', () async {
    const messages = <AgentMessage>[
      AgentHello(sessionId: 1, version: '0.1.0', userIsAdmin: true),
      LoginRequest(
        id: 7,
        appName: 'Minecraft',
        children: [
          (id: 'ivan', name: 'Иван', remainingSeconds: 600),
          (id: 'marina', name: 'Марина', remainingSeconds: null),
        ],
        error: LoginError.wrongPin,
      ),
      LoginReply(id: 7, childId: 'ivan', pin: '1234'),
      LoginReply.cancel(8),
      Notice(kind: NoticeKind.minutesLeft, childName: 'Иван', minutes: 5),
      AgentStatus(childName: 'Иван', remainingSeconds: 600),
      AgentStatus(),
      LogoutRequest(),
    ];

    final decoded = await decode([
      for (final message in messages) encodeAgentMessage(message),
    ]);

    expect(
      decoded.map((message) => message.toJson()),
      messages.map((message) => message.toJson()),
    );
    final request = decoded[1] as LoginRequest;
    expect(request.children.last.name, 'Марина');
    expect(request.children.first.remainingSeconds, 600);
    expect(request.children.last.remainingSeconds, isNull);
    expect(request.error, LoginError.wrongPin);
    expect((decoded[3] as LoginReply).cancelled, isTrue);
  });

  test(
    'messages split across chunks, including inside a UTF-8 letter',
    () async {
      final bytes = encodeAgentMessage(
        const Notice(kind: NoticeKind.timeUp, childName: 'Марина'),
      );
      final decoded = await decode([
        for (var i = 0; i < bytes.length; i += 3)
          bytes.sublist(i, i + 3 > bytes.length ? bytes.length : i + 3),
      ]);
      expect((decoded.single as Notice).childName, 'Марина');
    },
  );

  test('garbage and unknown messages are skipped', () async {
    final decoded = await decode([
      utf8.encode('not json\n{"type":"future"}\n[1]\n{"type":"login"}\n\n'),
      encodeAgentMessage(const LogoutRequest()),
    ]);
    expect(decoded.single, isA<LogoutRequest>());
  });

  test('an endless line ends the stream', () {
    expect(
      decodeAgentMessages(
        Stream.value(List.filled(100, 0x41)),
        maxLineBytes: 50,
      ).toList(),
      throwsFormatException,
    );
  });

  test('notices read well in logs', () {
    expect(
      const Notice(
        kind: NoticeKind.minutesLeft,
        childName: 'Ivan',
        minutes: 5,
      ).toString(),
      'Ivan: 5 min left',
    );
  });
}
