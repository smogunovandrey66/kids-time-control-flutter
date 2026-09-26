import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:win32/win32.dart';

import 'process_control.dart';

/// [ProcessControl] on top of WinAPI.
///
/// Uses `EnumProcesses` + `QueryFullProcessImageName` for the list, and the
/// undocumented but stable ntdll functions for the command line
/// (`NtQueryInformationProcess`, class 60, Windows 8.1+) and for
/// suspending/resuming whole processes.
final class WindowsProcessControl implements ProcessControl {
  static const _maxProcesses = 8192;
  static const _maxPath = 32768;

  @override
  List<ProcessInfo> list() => using((arena) {
    final pids = arena<Uint32>(_maxProcesses);
    final bytesReturned = arena<Uint32>();
    if (!EnumProcesses(
      pids,
      _maxProcesses * sizeOf<Uint32>(),
      bytesReturned,
    ).value) {
      return const [];
    }

    final count = bytesReturned.value ~/ sizeOf<Uint32>();
    return [for (var i = 0; i < count; i++) ?_read(pids[i])];
  });

  @override
  bool terminate(int pid) => _withProcess(
    pid,
    PROCESS_TERMINATE,
    (handle) => TerminateProcess(handle, 1).value,
  );

  @override
  bool suspend(int pid) => _withProcess(
    pid,
    PROCESS_SUSPEND_RESUME,
    (handle) => _ntSuspendProcess(handle) == 0,
  );

  @override
  bool resume(int pid) => _withProcess(
    pid,
    PROCESS_SUSPEND_RESUME,
    (handle) => _ntResumeProcess(handle) == 0,
  );

  ProcessInfo? _read(int pid) {
    if (pid == 0) return null;
    return _withProcessOrNull(pid, PROCESS_QUERY_LIMITED_INFORMATION, (handle) {
      final exePath = _imagePath(handle);
      if (exePath == null) return null;
      return ProcessInfo(
        pid: pid,
        exePath: exePath,
        commandLine: _commandLine(handle) ?? '',
      );
    });
  }

  static String? _imagePath(HANDLE handle) => using((arena) {
    final buffer = PWSTR(arena<Uint16>(_maxPath).cast());
    final size = arena<Uint32>()..value = _maxPath;
    if (!QueryFullProcessImageName(
      handle,
      PROCESS_NAME_WIN32,
      buffer,
      size,
    ).value) {
      return null;
    }
    return buffer.toDartString(length: size.value);
  });

  static String? _commandLine(HANDLE handle) => using((arena) {
    final needed = arena<Uint32>();
    // First call reports the required buffer size (STATUS_INFO_LENGTH_MISMATCH).
    _ntQueryInformationProcess(
      handle,
      _processCommandLineInformation,
      nullptr,
      0,
      needed,
    );
    if (needed.value == 0) return null;

    final buffer = arena<Uint8>(needed.value);
    final status = _ntQueryInformationProcess(
      handle,
      _processCommandLineInformation,
      buffer,
      needed.value,
      needed,
    );
    if (status != 0) return null;

    final text = buffer.cast<_UnicodeString>().ref;
    if (text.buffer == nullptr || text.length == 0) return '';
    return text.buffer.toDartString(length: text.length ~/ 2);
  });

  static bool _withProcess(
    int pid,
    PROCESS_ACCESS_RIGHTS access,
    bool Function(HANDLE handle) action,
  ) => _withProcessOrNull(pid, access, action) ?? false;

  static T? _withProcessOrNull<T extends Object>(
    int pid,
    PROCESS_ACCESS_RIGHTS access,
    T? Function(HANDLE handle) action,
  ) {
    final handle = OpenProcess(access, false, pid).value;
    if (!handle.isValid) return null;
    try {
      return action(handle);
    } finally {
      handle.close();
    }
  }
}

// ntdll functions that the win32 package does not expose.
const _processCommandLineInformation = 60;

final _ntdll = DynamicLibrary.open('ntdll.dll');

final _ntQueryInformationProcess = _ntdll
    .lookupFunction<
      Int32 Function(Pointer, Int32, Pointer, Uint32, Pointer<Uint32>),
      int Function(Pointer, int, Pointer, int, Pointer<Uint32>)
    >('NtQueryInformationProcess');

final _ntSuspendProcess = _ntdll
    .lookupFunction<Int32 Function(Pointer), int Function(Pointer)>(
      'NtSuspendProcess',
    );

final _ntResumeProcess = _ntdll
    .lookupFunction<Int32 Function(Pointer), int Function(Pointer)>(
      'NtResumeProcess',
    );

/// UNICODE_STRING: lengths are in bytes, the buffer is not null-terminated.
final class _UnicodeString extends Struct {
  @Uint16()
  external int length;

  @Uint16()
  external int maximumLength;

  external Pointer<Utf16> buffer;
}
