import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  final rules = [
    const AppRule(
      id: 'minecraft',
      name: 'Minecraft',
      exeName: 'javaw.exe',
      commandLineContains: 'minecraft',
    ),
  ];

  test('counts time only while a game runs', () {
    final control = FakeProcessControl([browser]);
    final monitor = GameMonitor(
      processes: control,
      matcher: AppMatcher(rules),
      tracker: UsageTracker(limit: const Duration(hours: 1)),
    );

    expect(monitor.tick(const Duration(seconds: 2)).games, isEmpty);
    control.processes.add(minecraft);
    final tick = monitor.tick(const Duration(seconds: 2));

    expect(tick.games.single.app.id, 'minecraft');
    expect(monitor.tracker.used, const Duration(seconds: 2));
  });

  test('closeAll terminates only games', () {
    final control = FakeProcessControl([minecraft, browser]);
    final monitor = GameMonitor(
      processes: control,
      matcher: AppMatcher(rules),
      tracker: UsageTracker(limit: Duration.zero),
    );

    expect(monitor.closeAll(monitor.runningGames()), [100]);
    expect(control.processes, [browser]);
  });
}
