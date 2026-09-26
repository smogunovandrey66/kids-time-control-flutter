import 'package:ktc_core/ktc_core.dart';

/// What the child entered in the "Who is playing?" window.
typedef LoginAnswer = ({String childId, String pin});

/// The service's window to the user. [AgentServer] talks to the tray agent;
/// `ktc service --console` uses the console; tests use a fake.
abstract interface class LoginBroker {
  /// Asks who is playing [appName]. `null` means cancelled or no agent is available.
  Future<LoginAnswer?> askLogin({
    required List<Child> children,
    required String appName,
    LoginError? previousError,
  });

  /// A notification for the child at the PC ("5 minutes left", "time is up").
  void notify(Notice notice);
}

/// Used when no agent is available: nobody can log in, so games are closed.
final class NoAgentBroker implements LoginBroker {
  NoAgentBroker(this._log);

  final void Function(String message) _log;

  @override
  Future<LoginAnswer?> askLogin({
    required List<Child> children,
    required String appName,
    LoginError? previousError,
  }) async {
    _log('No tray agent available to ask who is playing $appName: closing it.');
    return null;
  }

  @override
  void notify(Notice notice) => _log('Notification: $notice');
}
