import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'session_state.dart';

/// [SessionState] via the Remote Desktop Services API (works for the local
/// console too, Windows 8+).
final class WindowsSessionState implements SessionState {
  static const _noSession = 0xFFFFFFFF;

  @override
  int activeSessionId() => _wtsGetActiveConsoleSessionId();

  @override
  bool isLocked() {
    final session = activeSessionId();
    if (session == _noSession) return true; // switching users

    return using((arena) {
      final buffer = arena<Pointer<Uint8>>();
      final bytes = arena<Uint32>();
      final ok = _wtsQuerySessionInformation(
        nullptr, // WTS_CURRENT_SERVER_HANDLE
        session,
        _wtsSessionInfoEx,
        buffer,
        bytes,
      );
      if (ok == 0 || buffer.value == nullptr) return false;
      try {
        // WTSINFOEXW: DWORD Level; then (8-byte aligned) WTSINFOEX_LEVEL1_W:
        // ULONG SessionId; WTS_CONNECTSTATE_CLASS SessionState; LONG SessionFlags.
        final data = buffer.value;
        final state = (data + 12).cast<Int32>().value;
        final flags = (data + 16).cast<Int32>().value;
        if (state != _wtsActive) return true; // logon screen, disconnected
        // WTS_SESSIONSTATE_UNKNOWN (-1) counts as unlocked: better to let the
        // child log in than to keep games suspended forever.
        return flags == _wtsSessionStateLock;
      } finally {
        _wtsFreeMemory(buffer.value);
      }
    });
  }
}

const _wtsSessionInfoEx = 25; // WTS_INFO_CLASS.WTSSessionInfoEx
const _wtsActive = 0; // WTS_CONNECTSTATE_CLASS.WTSActive
const _wtsSessionStateLock = 0;

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _wtsapi32 = DynamicLibrary.open('wtsapi32.dll');

final _wtsGetActiveConsoleSessionId = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>(
      'WTSGetActiveConsoleSessionId',
    );

final _wtsQuerySessionInformation = _wtsapi32
    .lookupFunction<
      Int32 Function(
        Pointer,
        Uint32,
        Int32,
        Pointer<Pointer<Uint8>>,
        Pointer<Uint32>,
      ),
      int Function(Pointer, int, int, Pointer<Pointer<Uint8>>, Pointer<Uint32>)
    >('WTSQuerySessionInformationW');

final _wtsFreeMemory = _wtsapi32
    .lookupFunction<Void Function(Pointer), void Function(Pointer)>(
      'WTSFreeMemory',
    );
