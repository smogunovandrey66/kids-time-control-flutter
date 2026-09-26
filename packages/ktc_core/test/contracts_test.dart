// The shared examples are the contract between the PC, the parent app and
// Firestore: the Dart models must read them and write back the same JSON.
import 'dart:convert';
import 'dart:io';

import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

Map<String, Object?> example(String name) =>
    jsonDecode(File('../../shared/examples/$name.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('child example round-trips and its PIN hash verifies', () {
    final json = example('child');
    final child = Child.fromJson('ivan', json);

    expect(child.name, 'Иван');
    expect(
      child.limits.secondsFor(DateTime(2026, 9, 26)),
      7200,
      reason: 'Saturday',
    );
    expect(
      child.limits.secondsFor(DateTime(2026, 9, 28)),
      3600,
      reason: 'Monday',
    );
    expect(verifyPin('1234', child.pinHash), isTrue);

    expect(child.toJson(), json);
    expect(
      child.limitFor(DateTime(2026, 9, 26)),
      const Duration(seconds: 7200 + 900),
    );
    expect(
      child.limitFor(DateTime(2026, 9, 27)),
      const Duration(seconds: 7200),
    );
  });

  test('app example round-trips and matches Minecraft', () {
    final json = example('app');
    final app = AppRule.fromJson('minecraft', json);

    expect(app.toJson(), json);
    expect(
      AppMatcher.ruleMatches(
        app,
        const ProcessInfo(
          pid: 1,
          exePath: r'C:\Java\bin\javaw.exe',
          commandLine: 'javaw.exe net.minecraft.client.main.Main',
        ),
      ),
      isTrue,
    );
  });

  test('config example lists children and games', () {
    final config = LocalConfig.fromJson(example('config'));

    expect(config.child('ivan')?.name, 'Иван');
    expect(config.child('nobody'), isNull);
    expect(config.apps.map((app) => app.id), ['minecraft', 'roblox']);
    expect(config.toJson(), example('config'));
  });

  test('family, device and usage examples round-trip', () {
    final family = example('family');
    expect(Family.fromJson('f1', family).toJson(), family);

    final device = Device.fromJson('pc', example('device'));
    expect(device.activeChildId, 'ivan');
    expect(device.isOnline(DateTime.utc(2026, 9, 26, 16, 43)), isTrue);
    expect(device.isOnline(DateTime.utc(2026, 9, 26, 17)), isFalse);
    expect(device.isOnline(DateTime.utc(2026, 9, 26, 16, 50)), isTrue);
    expect(device.userIsAdmin, isFalse);
    expect(device.programs.first.fileName, 'RobloxPlayerBeta.exe');
    expect(
      device.toJson()['programs'],
      example('device')['programs'],
      reason: 'lastSeen differs only in formatting',
    );
    final rule = device.programs.first.suggestRule('roblox');
    expect(
      (rule.name, rule.exeName),
      ('RobloxPlayerBeta', 'RobloxPlayerBeta.exe'),
    );

    final usage = example('usage');
    final daily = DailyUsage.fromJson(usage);
    expect(daily.apps, {'minecraft': 2400, 'roblox': 600});
    expect(DailyUsage.documentId(daily.childId, daily.date), 'ivan_2026-09-26');
    expect(
      jsonEncode(daily.toJson()),
      jsonEncode(usage).replaceAll('Z"', '.000Z"'),
    );
  });
}
