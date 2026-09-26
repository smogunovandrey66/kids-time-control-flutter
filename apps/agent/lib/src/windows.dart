import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:win32/win32.dart';

import 'agent_controller.dart';

/// The Windows session this agent runs in (one agent per logged-on user).
int currentSessionId() => using((arena) {
  final session = arena<Uint32>();
  return ProcessIdToSessionId(GetCurrentProcessId(), session).value
      ? session.value
      : 0;
});

/// Whether the Windows user running the agent is an administrator. Such a
/// user (a child included) could stop the service, so the parent is warned.
bool currentUserIsAdmin() {
  final elevated = using((arena) {
    final token = arena<Pointer>();
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, token).value) {
      return false;
    }
    final handle = HANDLE(token.value);
    try {
      final type = arena<Int32>();
      final length = arena<Uint32>();
      // TokenElevationTypeDefault (1) is a standard user or UAC turned off;
      // Full (2) and Limited (3) mean an administrator under UAC.
      return GetTokenInformation(
            handle,
            TokenElevationType,
            type,
            sizeOf<Int32>(),
            length,
          ).value &&
          type.value != _tokenElevationTypeDefault;
    } finally {
      handle.close();
    }
  });
  return elevated || _isUserAnAdmin() != 0;
}

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
const _tokenElevationTypeDefault = 1;

final _isUserAnAdmin = DynamicLibrary.open(
  'shell32.dll',
).lookupFunction<Int32 Function(), int Function()>('IsUserAnAdmin');

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
