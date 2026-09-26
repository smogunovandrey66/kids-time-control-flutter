import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:win32/win32.dart'
    show GetCurrentProcessId, ProcessIdToSessionId;

import 'agent_controller.dart';

/// The Windows session this agent runs in (one agent per logged-on user).
int currentSessionId() => using((arena) {
  final session = arena<Uint32>();
  return ProcessIdToSessionId(GetCurrentProcessId(), session).value
      ? session.value
      : 0;
});

/// `false` if another agent already runs in this Windows session. The mutex
/// lives as long as the process.
bool claimSingleInstance() => using((arena) {
  final name = r'Local\KidsTimeControlAgent'.toNativeUtf16(allocator: arena);
  if (_openMutex(_synchronize, 0, name) != nullptr) return false;
  _createMutex(nullptr, 0, name);
  return true;
});

/// Connects to the service on this PC.
Future<AgentChannel> connectToService({int port = agentPort}) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
    timeout: const Duration(seconds: 5),
  );
  return (
    messages: decodeAgentMessages(socket),
    send: (AgentMessage message) {
      try {
        socket.add(encodeAgentMessage(message));
      } on Object {
        // Lost; the message stream ends and the controller reconnects.
      }
    },
    close: socket.destroy,
  );
}

const _synchronize = 0x00100000;

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _openMutex = _kernel32
    .lookupFunction<
      Pointer Function(Uint32, Int32, Pointer<Utf16>),
      Pointer Function(int, int, Pointer<Utf16>)
    >('OpenMutexW');

final _createMutex = _kernel32
    .lookupFunction<
      Pointer Function(Pointer, Int32, Pointer<Utf16>),
      Pointer Function(Pointer, int, Pointer<Utf16>)
    >('CreateMutexW');
