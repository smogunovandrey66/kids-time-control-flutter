import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';

final class FakeProcessControl implements ProcessControl {
  FakeProcessControl(this.processes);

  final List<ProcessInfo> processes;
  final terminated = <int>[];

  @override
  List<ProcessInfo> list() => List.of(processes);

  @override
  bool terminate(int pid) {
    terminated.add(pid);
    processes.removeWhere((process) => process.pid == pid);
    return true;
  }

  @override
  bool suspend(int pid) => true;

  @override
  bool resume(int pid) => true;
}

const minecraft = ProcessInfo(
  pid: 100,
  exePath: r'C:\Program Files\Java\bin\javaw.exe',
  commandLine: 'javaw.exe -cp x net.minecraft.client.main.Main',
);
const notepad = ProcessInfo(
  pid: 200,
  exePath: r'C:\Windows\System32\notepad.exe',
);
const browser = ProcessInfo(
  pid: 300,
  exePath: r'C:\Program Files\Browser\browser.exe',
  commandLine: 'browser.exe --new-window',
);

/// PIN of the child "ivan" in [configJson] is 1234.
const configJson = r'''
{
  "children": {
    "ivan": {
      "name": "Ivan",
      "pinHash": "pbkdf2-sha256$10000$a3RjLXRlc3Qtc2FsdA==$LxrtrmK164FUMoBkx/0kVzkUUXAlTlK3MCyFqTb7Tsc=",
      "limits": { "weekdaySeconds": 3600, "weekendSeconds": 3600 },
      "archived": false
    }
  },
  "apps": {
    "minecraft": {
      "name": "Minecraft",
      "match": { "exeName": "javaw.exe", "commandLineContains": "minecraft" },
      "archived": false
    }
  }
}
''';
