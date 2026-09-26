@TestOn('windows')
library;

import 'dart:io';

import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

/// Runs against the real WinAPI on Windows (CI: windows-latest).
void main() {
  final control = WindowsProcessControl();

  test('lists the current process with its path and command line', () {
    final self = control.list().firstWhere((process) => process.pid == pid);

    expect(self.exePath.toLowerCase(), endsWith('.exe'));
    expect(File(self.exePath).existsSync(), isTrue);
    expect(self.commandLine, isNotEmpty);
  });

  test('suspends, resumes and terminates a process', () async {
    final child = await Process.start('ping', ['-n', '60', '127.0.0.1']);
    addTearDown(() => child.kill());

    final info = control.list().firstWhere(
      (process) => process.pid == child.pid,
    );
    expect(info.exePath.toLowerCase(), endsWith(r'\ping.exe'));
    expect(info.commandLine, contains('127.0.0.1'));

    expect(control.suspend(child.pid), isTrue);
    expect(control.resume(child.pid), isTrue);
    expect(control.terminate(child.pid), isTrue);
    expect(await child.exitCode.timeout(const Duration(seconds: 10)), 1);
  });
}
