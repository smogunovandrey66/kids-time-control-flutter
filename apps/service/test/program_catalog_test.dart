import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

void main() {
  ProcessInfo process(String path, {int pid = 1, int? session = 1}) =>
      ProcessInfo(pid: pid, exePath: path, sessionId: session);

  const tick = Duration(seconds: 2);
  const roblox = r'C:\Users\Ivan\AppData\Local\Roblox\RobloxPlayerBeta.exe';
  const chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe';

  test('counts user programs once per tick, most used first', () {
    final catalog = ProgramCatalog();
    for (var i = 0; i < 30; i++) {
      catalog.observe(
        [
          process(roblox),
          process(chrome, pid: 2),
          process(chrome, pid: 3), // many processes, one program
          if (i < 5) process(r'D:\Games\Other.exe', pid: 4),
        ],
        tick,
        '2026-09-28',
      );
    }

    final top = catalog.top('2026-09-28');
    expect(top.map((program) => program.exePath), [
      roblox,
      chrome,
      r'D:\Games\Other.exe',
    ]);
    expect(top.map((program) => program.seconds), [60, 60, 10]);
  });

  test('skips Windows, services, the agent and sleep gaps', () {
    final catalog = ProgramCatalog()
      ..observe(
        [
          process(r'C:\Windows\explorer.exe'),
          process(r'c:\windows\System32\svchost.exe'),
          process(r'C:\Program Files\Service\service.exe', session: 0),
          process(r'C:\Program Files\KidsTimeControl\agent\ktc_agent.exe'),
          process(roblox),
        ],
        tick,
        '2026-09-28',
      )
      ..observe([process(roblox)], const Duration(hours: 1), '2026-09-28');

    final top = catalog.top('2026-09-28');
    expect(top.single.exePath, roblox);
    expect(top.single.seconds, 2, reason: 'the hour of sleep is not counted');
  });

  test('forgets programs not seen for two weeks; survives a restart', () {
    final catalog = ProgramCatalog()
      ..observe([process(roblox)], tick, '2026-09-01')
      ..observe([process(chrome)], tick, '2026-09-20');

    final restored = ProgramCatalog()..load(catalog.toJson('2026-09-10'));
    expect(restored.top('2026-09-10'), hasLength(2));
    expect(restored.top('2026-09-28').single.exePath, chrome);
  });

  test('keeps at most maxPrograms', () {
    final catalog = ProgramCatalog(maxPrograms: 3);
    catalog.observe(
      [for (var i = 0; i < 10; i++) process('D:\\Games\\g$i.exe', pid: i)],
      tick,
      '2026-09-28',
    );
    expect(catalog.top('2026-09-28'), hasLength(3));
  });
}
