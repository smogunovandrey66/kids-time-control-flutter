import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ktc_core/ktc_core.dart';

/// A connection to the service (a socket in the app, streams in tests).
typedef AgentChannel = ({
  Stream<AgentMessage> messages,
  void Function(AgentMessage message) send,
  void Function() close,
});

/// State of the agent: connection, the "Who is playing?" question, the
/// current notification and who is playing. The UI and the tray listen to it.
///
/// Reconnects every [retry] while the service is not reachable (it may start
/// after the agent or be restarted).
class AgentController extends ChangeNotifier {
  AgentController({
    required Future<AgentChannel> Function() connect,
    required this.sessionId,
    this.userIsAdmin = false,
    this.version = '',
    this.retry = const Duration(seconds: 3),
    this.noticeDuration = const Duration(seconds: 10),
  }) : _connect = connect;

  final Future<AgentChannel> Function() _connect;
  final int sessionId;
  final bool userIsAdmin;
  final String version;
  final Duration retry;
  final Duration noticeDuration;

  AgentChannel? _channel;
  StreamSubscription<AgentMessage>? _subscription;
  Timer? _retryTimer;
  Timer? _noticeTimer;
  var _disposed = false;

  bool get connected => _channel != null;

  /// The open question, if any.
  LoginRequest? get prompt => _prompt;
  LoginRequest? _prompt;

  /// The notification being shown, if any.
  Notice? get notice => _notice;
  Notice? _notice;

  AgentStatus get status => _status;
  AgentStatus _status = const AgentStatus();

  /// Connects now and keeps reconnecting.
  void start() => unawaited(_tryConnect());

  Future<void> _tryConnect() async {
    if (_disposed || _channel != null) return;
    try {
      final channel = await _connect();
      if (_disposed) return channel.close();
      _channel = channel;
      _subscription = channel.messages.listen(
        _handle,
        onError: (Object _) => _lost(),
        onDone: _lost,
      );
      channel.send(
        AgentHello(
          sessionId: sessionId,
          version: version,
          userIsAdmin: userIsAdmin,
        ),
      );
      notifyListeners();
    } on Object {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(retry, () => unawaited(_tryConnect()));
  }

  void _lost() {
    if (_channel == null) return;
    unawaited(_subscription?.cancel());
    _channel!.close();
    _channel = null;
    _prompt = null; // the service will not get the answer
    _status = const AgentStatus();
    notifyListeners();
    _scheduleRetry();
  }

  void _handle(AgentMessage message) {
    switch (message) {
      case LoginRequest():
        _prompt = message;
      case Notice():
        _notice = message;
        _noticeTimer?.cancel();
        _noticeTimer = Timer(noticeDuration, dismissNotice);
      case AgentStatus():
        _status = message;
      case AgentHello() || LoginReply() || LogoutRequest():
        return; // agent → service only
    }
    notifyListeners();
  }

  /// The child picked their name and typed the PIN.
  void answer(String childId, String pin) =>
      _reply(LoginReply(id: _prompt!.id, childId: childId, pin: pin));

  void cancel() => _reply(LoginReply.cancel(_prompt!.id));

  void _reply(LoginReply reply) {
    _channel?.send(reply);
    _prompt = null;
    notifyListeners();
  }

  void dismissNotice() {
    _noticeTimer?.cancel();
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// "Log out": the next game asks who is playing again.
  void logout() => _channel?.send(const LogoutRequest());

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _noticeTimer?.cancel();
    unawaited(_subscription?.cancel());
    _channel?.close();
    super.dispose();
  }
}
