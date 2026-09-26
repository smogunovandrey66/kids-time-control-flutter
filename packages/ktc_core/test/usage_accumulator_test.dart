import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  const empty = DailyUsage(
    childId: 'ivan',
    date: '2026-09-28',
    totalSeconds: 0,
  );

  test('adds time to the total and to every running app', () {
    var usage = accumulateUsage(
      empty,
      2,
      runningAppIds: {'minecraft', 'roblox'},
    );
    usage = accumulateUsage(usage, 3, runningAppIds: {'minecraft'});

    expect(usage.totalSeconds, 5);
    expect(usage.apps, {'minecraft': 5, 'roblox': 2});
  });

  test('nothing is added while no game runs', () {
    expect(accumulateUsage(empty, 2, runningAppIds: {}).totalSeconds, 0);
  });
}
