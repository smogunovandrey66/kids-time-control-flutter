/// Who is at the screen. Windows: [WindowsSessionState]; elsewhere and in
/// tests: [NoSessionState].
abstract interface class SessionState {
  /// The Windows session attached to the physical console (screen and keyboard).
  int activeSessionId();

  /// Nobody can use the PC right now: the screen is locked, or the logon
  /// screen is shown.
  bool isLocked();
}

final class NoSessionState implements SessionState {
  const NoSessionState();

  @override
  int activeSessionId() => 0;

  @override
  bool isLocked() => false;
}
