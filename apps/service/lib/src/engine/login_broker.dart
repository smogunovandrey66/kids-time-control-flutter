import 'package:ktc_core/ktc_core.dart';

/// Why the previous login attempt was rejected (shown to the child).
enum LoginError { wrongPin, locked, noTimeLeft }

/// What the child entered in the "Who is playing?" window.
typedef LoginAnswer = ({String childId, String pin});

/// The service's window to the user. The tray agent implements it over a
/// named pipe; `ktc service --console` uses the console; tests use a fake.
abstract interface class LoginBroker {
  /// Asks who is playing [appName]. `null` means cancelled or no agent is available.
  Future<LoginAnswer?> askLogin({
    required List<Child> children,
    required String appName,
    LoginError? previousError,
  });

  /// A notification for the child at the PC ("5 minutes left", "time is up").
  void notify(String message);
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
  void notify(String message) => _log('Notification: $message');
}
