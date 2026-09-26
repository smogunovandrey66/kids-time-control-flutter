import 'dart:async';
import 'dart:io';

import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

import 'fakes.dart';

final class FakeBroker implements LoginBroker {
  /// Answers for the next login prompts, in order; `null` means "cancel".
  final answers = <LoginAnswer?>[];
  final prompts = <LoginError?>[];
  final notifications = <String>[];

  @override
  Future<LoginAnswer?> askLogin({
    required List<Child> children,
    required String appName,
    LoginError? previousError,
  }) async {
    prompts.add(previousError);
    return answers.isEmpty ? null : answers.removeAt(0);
  }

  @override
  void notify(String message) => notifications.add(message);
}

/// Minecraft started again: a new process.
ProcessInfo relaunched(int pid) => ProcessInfo(
  pid: pid,
  exePath: minecraft.exePath,
  commandLine: minecraft.commandLine,
);

void main() {
  late FakeProcessControl processes;
  late FakeBroker broker;
  late DataDir dir;
  late ServiceEngine engine;
  var now = Duration.zero;
  final wallClock = DateTime(2026, 9, 28, 18); // Monday

  LocalConfig config({int weekdayMinutes = 60, Bonus? bonus}) => LocalConfig(
    children: [
      Child(
        id: 'ivan',
        name: 'Ivan',
        pinHash: hashPin('1234', iterations: 1),
        limits: Limits(weekdaySeconds: weekdayMinutes * 60, weekendSeconds: 0),
        bonus: bonus,
      ),
      Child(
        id: 'marina',
        name: 'Marina',
        pinHash: hashPin('5678', iterations: 1),
        limits: const Limits(weekdaySeconds: 3600, weekendSeconds: 0),
      ),
    ],
    apps: const [
      AppRule(
        id: 'minecraft',
        name: 'Minecraft',
        exeName: 'javaw.exe',
        commandLineContains: 'minecraft',
      ),
    ],
  );

  /// Advances time by [seconds] in 2-second ticks, letting pending logins complete.
  Future<void> run(int seconds) async {
    for (var i = 0; i < seconds ~/ 2; i++) {
      now += const Duration(seconds: 2);
      engine.tick(const Duration(seconds: 2));
      await pumpEventQueue();
    }
  }

  setUp(() {
    now = Duration.zero;
    processes = FakeProcessControl([browser]);
    broker = FakeBroker();
    dir = DataDir(Directory.systemTemp.createTempSync('ktc_engine').path);
    engine = ServiceEngine(
      processes: processes,
      broker: broker,
      dir: dir,
      wallClock: () => wallClock.add(now),
      monotonicNow: () => now,
      config: config(),
      idleTimeout: const Duration(minutes: 1),
      closeGrace: const Duration(seconds: 10),
    );
  });

  test('without games nothing happens', () async {
    await run(10);
    expect(broker.prompts, isEmpty);
    expect(processes.suspended, isEmpty);
  });

  test('a game is suspended until the right PIN, then resumed', () async {
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);

    await run(2);

    expect(processes.suspended, [100]);
    expect(processes.resumed, [100]);
    expect(engine.activeChildId, 'ivan');
    expect(processes.terminated, isEmpty);
  });

  test('wrong PINs and cancel close the game', () async {
    broker.answers.addAll([(childId: 'ivan', pin: '0000'), null]);
    processes.processes.add(minecraft);

    await run(2);

    expect(broker.prompts, [null, LoginError.wrongPin]);
    expect(processes.terminated, [100]);
    expect(engine.activeChildId, isNull);
  });

  test('five wrong PINs lock the profile', () async {
    for (var i = 0; i < 6; i++) {
      broker.answers.add((childId: 'ivan', pin: '0000'));
    }
    processes.processes.add(minecraft);
    await run(2);
    processes.processes.add(relaunched(101));
    await run(2);

    expect(broker.prompts, [
      null, LoginError.wrongPin, LoginError.wrongPin, // first game: 3 attempts
      null,
      LoginError.wrongPin,
      LoginError.locked, // second game: 5th failure locks
    ]);
    // Even the right PIN is rejected while locked.
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(relaunched(102));
    await run(2);
    expect(broker.prompts.last, LoginError.locked);
    expect(engine.activeChildId, isNull);
  });

  test('no time left today: the game is closed', () async {
    dir.saveUsage(
      const DailyUsage(childId: 'ivan', date: '2026-09-28', totalSeconds: 3600),
    );
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);

    await run(2);

    expect(processes.terminated, [100]);
    expect(broker.notifications.single, contains('no time left'));
  });

  test(
    'accounts time, warns, and closes games after the grace period',
    () async {
      engine.updateConfig(config(weekdayMinutes: 2));
      broker.answers.add((childId: 'ivan', pin: '1234'));
      processes.processes.add(minecraft);
      await run(2); // login

      await run(120);

      final usage = dir.loadUsage('ivan', '2026-09-28');
      expect(usage.totalSeconds, 120);
      expect(usage.apps, {'minecraft': 120});
      expect(engine.takeDirtyUsage().single.totalSeconds, 120);
      expect(broker.notifications.first, contains('Ivan: 2 min left'));
      expect(broker.notifications.last, contains('time is up'));
      expect(processes.terminated, isEmpty, reason: 'grace period');

      await run(10);
      expect(processes.terminated, [100]);
      expect(engine.activeChildId, isNull, reason: 'closing ends the session');
    },
  );

  test('after time is up a sister can log in right away', () async {
    engine.updateConfig(config(weekdayMinutes: 1));
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);
    await run(2);
    await run(70); // 60 s of play + 10 s grace
    expect(processes.terminated, [100]);

    broker.answers.add((childId: 'marina', pin: '5678'));
    processes.processes.add(relaunched(101));
    await run(2);

    expect(engine.activeChildId, 'marina');
    expect(processes.terminated, [100]);
  });

  test('a game that is slow to exit is not asked about again', () async {
    processes.slowExit = true;
    processes.processes.add(minecraft);
    await run(2); // nobody answers: the game is closed
    expect(processes.terminated, [100]);

    await run(8);
    expect(broker.prompts, hasLength(1));

    // Still alive after 10 s: handled again.
    await run(4);
    expect(broker.prompts, hasLength(2));
  });

  test('extra time after time is up restarts the grace period', () async {
    engine.updateConfig(config(weekdayMinutes: 1));
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);
    await run(2);
    await run(64); // time is up, 4 s into the grace period
    engine.updateConfig(
      config(
        weekdayMinutes: 1,
        bonus: const Bonus(date: '2026-09-28', seconds: 60),
      ),
    );
    await run(56); // the rest of the extra minute
    await run(8);
    expect(processes.terminated, isEmpty, reason: 'a new grace period');
    await run(2);
    expect(processes.terminated, [100]);
  });

  test('the session ends after a while without games', () async {
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);
    await run(2);
    processes.processes.remove(minecraft);

    // Idle time counts from the first tick without games (t = 4 s).
    await run(56);
    expect(engine.activeChildId, 'ivan');
    await run(6);
    expect(engine.activeChildId, isNull);

    // The next game asks again.
    processes.processes.add(minecraft);
    await run(2);
    expect(broker.prompts, hasLength(2));
  });

  test('a bonus from the parent applies to the running session', () async {
    engine.updateConfig(config(weekdayMinutes: 1));
    broker.answers.add((childId: 'ivan', pin: '1234'));
    processes.processes.add(minecraft);
    await run(2);
    await run(60);
    expect(broker.notifications.last, contains('time is up'));

    engine.updateConfig(
      config(
        weekdayMinutes: 1,
        bonus: const Bonus(date: '2026-09-28', seconds: 600),
      ),
    );
    await run(20);

    expect(processes.terminated, isEmpty);
  });
}
