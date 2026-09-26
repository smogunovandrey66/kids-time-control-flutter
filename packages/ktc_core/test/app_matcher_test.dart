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

  test('matches any program in a folder, whatever it is called', () {
    const rule = AppRule(
      id: 'roblox',
      name: 'Roblox',
      folder: r'C:\Users\*\AppData\Local\Roblox\',
    );

    for (final path in [
      r'C:\Users\Ivan\AppData\Local\Roblox\Versions\v1\RobloxPlayerBeta.exe',
      r'c:\users\marina\appdata\local\roblox\renamed.exe',
      'C:/Users/Ivan/AppData/Local/Roblox/x.exe',
    ]) {
      expect(AppMatcher.ruleMatches(rule, process(path)), isTrue, reason: path);
    }
    for (final path in [
      r'C:\Users\Ivan\AppData\Local\RobloxOld\x.exe',
      r'C:\Users\Ivan\AppData\Local\Roblox',
      r'C:\Users\AppData\Local\Roblox\x.exe',
      r'D:\Users\Ivan\AppData\Local\Roblox\x.exe',
    ]) {
      expect(
        AppMatcher.ruleMatches(rule, process(path)),
        isFalse,
        reason: path,
      );
    }
  });

  test('a star can be part of a folder name', () {
    expect(
      AppMatcher.isInFolder(r'D:\Games\Steam1\a.exe', r'D:\Games\Steam*'),
      isTrue,
    );
    expect(
      AppMatcher.isInFolder(r'D:\Games\Epic\a.exe', r'D:\Games\Steam*'),
      isFalse,
    );
  });
}
