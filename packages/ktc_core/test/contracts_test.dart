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

    final expected = Map.of(json)..remove('bonus');
    expect(child.toJson(), expected);
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
}
