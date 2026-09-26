import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  ProcessInfo process(String exePath, [String commandLine = '']) =>
      ProcessInfo(pid: 42, exePath: exePath, commandLine: commandLine);

  test('matches the full path ignoring case', () {
    const rule = AppRule(
      id: 'game',
      name: 'Game',
      exePath: r'C:\Games\Game.exe',
    );

    expect(AppMatcher.ruleMatches(rule, process(r'c:\games\GAME.EXE')), isTrue);
    expect(AppMatcher.ruleMatches(rule, process(r'C:\Copy\Game.exe')), isFalse);
  });

  test('matches the exe name in any folder', () {
    const rule = AppRule(
      id: 'roblox',
      name: 'Roblox',
      exeName: 'RobloxPlayerBeta.exe',
    );

    expect(
      AppMatcher.ruleMatches(
        rule,
        process(
          r'C:\Users\Kid\AppData\Local\Roblox\Versions\v1\robloxplayerbeta.exe',
        ),
      ),
      isTrue,
    );
  });

  test('requires every criterion (Minecraft runs as javaw.exe)', () {
    const minecraft = AppRule(
      id: 'minecraft',
      name: 'Minecraft',
      exeName: 'javaw.exe',
      commandLineContains: 'minecraft',
    );

    expect(
      AppMatcher.ruleMatches(
        minecraft,
        process(
          r'C:\Java\bin\javaw.exe',
          'javaw.exe -cp ... net.minecraft.client.main.Main',
        ),
      ),
      isTrue,
    );
    expect(
      AppMatcher.ruleMatches(
        minecraft,
        process(r'C:\Java\bin\javaw.exe', 'javaw.exe -jar school.jar'),
      ),
      isFalse,
    );
  });

  test('a rule without criteria never matches', () {
    const rule = AppRule(id: 'empty', name: 'Empty', exeName: '');

    expect(
      AppMatcher.ruleMatches(rule, process(r'C:\Windows\notepad.exe')),
      isFalse,
    );
  });

  test('returns the first matching rule and skips archived ones', () {
    final matcher = AppMatcher(const [
      AppRule(id: 'old', name: 'Old', exeName: 'game.exe', archived: true),
      AppRule(id: 'other', name: 'Other', exeName: 'other.exe'),
      AppRule(id: 'game', name: 'Game', exeName: 'game.exe'),
    ]);

    expect(matcher.match(process(r'D:\game.exe'))?.id, 'game');
    expect(matcher.match(process(r'D:\notepad.exe')), isNull);
  });
}
