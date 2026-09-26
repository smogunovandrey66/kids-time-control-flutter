import 'dart:async';
import 'dart:convert';

/// Messages between the Windows service and the tray agent.
///
/// The service listens on `127.0.0.1:`[agentPort]; the agent in each Windows
/// session connects and says [AgentHello]. Messages are JSON objects, one per
/// line (UTF-8). Any local program can connect, so the agent is trusted with
/// nothing: it only relays what the child types, and the service checks the PIN.
const agentPort = 47291;

/// Why the previous login attempt was rejected (shown to the child).
enum LoginError { wrongPin, locked, noTimeLeft }

sealed class AgentMessage {
  const AgentMessage();

  Map<String, Object?> toJson();

  /// Parses a message; `null` for unknown or malformed ones (newer peer).
  static AgentMessage? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      return switch (json['type']) {
        'hello' => AgentHello(
          sessionId: json['sessionId']! as int,
          version: json['version'] as String? ?? '',
          userIsAdmin: json['userIsAdmin'] as bool? ?? false,
        ),
        'login' => LoginRequest(
          id: json['id']! as int,
          appName: json['appName']! as String,
          children: [
            for (final child
                in (json['children']! as List<Object?>)
                    .cast<Map<String, Object?>>())
              (
                id: child['id']! as String,
                name: child['name']! as String,
                remainingSeconds: child['remainingSeconds'] as int?,
              ),
          ],
          error: switch (json['error']) {
            final String name => LoginError.values.asNameMap()[name],
            _ => null,
          },
        ),
        'loginReply' => LoginReply(
          id: json['id']! as int,
          childId: json['childId'] as String?,
          pin: json['pin'] as String?,
        ),
        'notice' => Notice(
          kind: NoticeKind.values.byName(json['kind']! as String),
          childName: json['childName']! as String,
          minutes: json['minutes'] as int? ?? 0,
        ),
        'status' => AgentStatus(
          childName: json['childName'] as String?,
          remainingSeconds: json['remainingSeconds'] as int?,
        ),
        'logout' => const LogoutRequest(),
        _ => null,
      };
    } on Object {
      return null; // wrong types or missing fields
    }
  }
}

/// Agent → service, first message: which Windows session the agent runs in.
final class AgentHello extends AgentMessage {
  const AgentHello({
    required this.sessionId,
    this.version = '',
    this.userIsAdmin = false,
  });

  final int sessionId;
  final String version;

  /// The Windows user of this session is an administrator: children using it
  /// could stop the service. Reported to the parent as a warning.
  final bool userIsAdmin;

  @override
  Map<String, Object?> toJson() => {
    'type': 'hello',
    'sessionId': sessionId,
    'version': version,
    'userIsAdmin': userIsAdmin,
  };
}

/// Service → agent: "Who is playing [appName]?".
final class LoginRequest extends AgentMessage {
  const LoginRequest({
    required this.id,
    required this.appName,
    required this.children,
    this.error,
  });

  final int id;
  final String appName;

  /// Time left today per child (`null` when the service could not tell).
  final List<({String id, String name, int? remainingSeconds})> children;

  /// Why the previous attempt failed, if this is a retry.
  final LoginError? error;

  @override
  Map<String, Object?> toJson() => {
    'type': 'login',
    'id': id,
    'appName': appName,
    'children': [
      for (final child in children)
        {
          'id': child.id,
          'name': child.name,
          'remainingSeconds': ?child.remainingSeconds,
        },
    ],
    'error': error?.name,
  };
}

/// Agent → service: the answer to [LoginRequest] [id]; no [childId] = cancel.
final class LoginReply extends AgentMessage {
  const LoginReply({required this.id, this.childId, this.pin});

  const LoginReply.cancel(this.id) : childId = null, pin = null;

  final int id;
  final String? childId;
  final String? pin;

  bool get cancelled => childId == null || pin == null;

  @override
  Map<String, Object?> toJson() => {
    'type': 'loginReply',
    'id': id,
    'childId': ?childId,
    'pin': ?pin,
  };
}

enum NoticeKind { minutesLeft, timeUp, noTimeLeft }

/// Service → agent: a notification for the child at the PC.
final class Notice extends AgentMessage {
  const Notice({required this.kind, required this.childName, this.minutes = 0});

  final NoticeKind kind;
  final String childName;

  /// For [NoticeKind.minutesLeft].
  final int minutes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'notice',
    'kind': kind.name,
    'childName': childName,
    'minutes': minutes,
  };

  /// English text for logs and the console.
  @override
  String toString() => switch (kind) {
    NoticeKind.minutesLeft => '$childName: $minutes min left',
    NoticeKind.timeUp => '$childName: time is up, games will be closed',
    NoticeKind.noTimeLeft => '$childName: no time left today',
  };
}

/// Service → agent: who is logged in and how much time is left (for the tray).
final class AgentStatus extends AgentMessage {
  const AgentStatus({this.childName, this.remainingSeconds});

  final String? childName;
  final int? remainingSeconds;

  @override
  Map<String, Object?> toJson() => {
    'type': 'status',
    'childName': childName,
    'remainingSeconds': remainingSeconds,
  };

  @override
  bool operator ==(Object other) =>
      other is AgentStatus &&
      other.childName == childName &&
      other.remainingSeconds == remainingSeconds;

  @override
  int get hashCode => Object.hash(childName, remainingSeconds);
}

/// Agent → service: the child pressed "Log out".
final class LogoutRequest extends AgentMessage {
  const LogoutRequest();

  @override
  Map<String, Object?> toJson() => const {'type': 'logout'};
}

/// One message as a line of JSON.
List<int> encodeAgentMessage(AgentMessage message) =>
    utf8.encode('${jsonEncode(message.toJson())}\n');

/// Splits bytes into messages. Unknown messages are skipped; a line longer
/// than [maxLineBytes] (garbage from a stray program) ends the stream with a
/// [FormatException].
Stream<AgentMessage> decodeAgentMessages(
  Stream<List<int>> bytes, {
  int maxLineBytes = 64 * 1024,
}) async* {
  final buffer = <int>[];
  await for (final chunk in bytes) {
    for (final byte in chunk) {
      if (byte != 0x0A) {
        buffer.add(byte);
        if (buffer.length > maxLineBytes) {
          throw const FormatException('Agent message too long');
        }
        continue;
      }
      final line = utf8.decode(buffer, allowMalformed: true).trim();
      buffer.clear();
      if (line.isEmpty) continue;
      Object? json;
      try {
        json = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (AgentMessage.fromJson(json) case final message?) yield message;
    }
  }
}
