import 'dart:async';

import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

import 'fakes.dart';

/// Runs `ktc` with fakes; time advances only when the command sleeps.
final class Harness {
  Harness(List<ProcessInfo> processes, {this.input, this.stopAfterSleeps})
    : control = FakeProcessControl(processes);

  final FakeProcessControl control;
  final String? input;
  final int? stopAfterSleeps;
  final out = StringBuffer();
  var _now = Duration.zero;
  var _sleeps = 0;
  final _stop = Completer<void>();

  Future<int?> run(List<String> args) => buildCli(
    CliContext(
      out: out,
      processes: () => control,
      readLine: () => input,
      readFile: (_) => configJson,
      monotonicNow: () => _now,
      sleep: (duration) async {
        _now += duration;
        _sleeps++;
        if (_sleeps == stopAfterSleeps) _stop.complete();
      },
      stopRequested: stopAfterSleeps == null ? null : _stop.future,
    ),
  ).run(args);
}

void main() {
  group('processes', () {
    test(r'hides C:\Windows by default and sorts by path', () async {
      final harness = Harness([minecraft, notepad, browser]);

      await harness.run(['processes']);

      final output = harness.out.toString();
      expect(output, isNot(contains('notepad')));
      expect(output.indexOf('Browser'), lessThan(output.indexOf('Java')));
      expect(output, contains('2 process(es)'));
    });

    test('--all and --filter', () async {
      final harness = Harness([minecraft, notepad, browser]);

      await harness.run(['processes', '--all', '--filter', 'MINECRAFT']);

      expect(harness.out.toString(), contains('net.minecraft'));
      expect(harness.out.toString(), contains('1 process(es)'));
    });
  });

  test('match lists recognized games only', () async {
    final harness = Harness([minecraft, notepad, browser]);

    await harness.run(['match', '--config', 'config.json']);

    expect(harness.out.toString(), contains('minecraft (Minecraft)\t100'));
    expect(harness.out.toString(), contains('1 game process(es)'));
  });

  test('hash-pin prints a hash that verifies', () async {
    final harness = Harness([]);

    await harness.run(['hash-pin', '4321', '--iterations', '1000']);

    expect(verifyPin('4321', harness.out.toString().trim()), isTrue);
  });

  group('run', () {
    test('rejects a wrong PIN', () async {
      final harness = Harness([minecraft], input: '0000');

      final code = await harness.run([
        'run',
        '-c',
        'config.json',
        '--child',
        'ivan',
      ]);

      expect(code, 1);
      expect(harness.out.toString(), contains('Wrong PIN.'));
    });

    test('dry run warns and reports time up without closing games', () async {
      final harness = Harness([minecraft], input: '1234', stopAfterSleeps: 60);

      await harness.run([
        'run', '-c', 'config.json', '--child', 'ivan', //
        '--limit-minutes', '2', '--interval', '5',
      ]);

      final output = harness.out.toString();
      expect(output, contains('Playing: Minecraft'));
      expect(output, contains('WARNING: 1:00 left.'));
      expect(output, contains('Time is up. Dry run: would close Minecraft.'));
      expect(harness.control.terminated, isEmpty);
    });

    test('--enforce closes games when time is up', () async {
      final harness = Harness([minecraft, browser]);

      await harness.run([
        'run', '-c', 'config.json', '--child', 'ivan', '--pin', '1234', //
        '--limit-minutes', '1', '--interval', '2', '--enforce',
      ]);

      expect(harness.control.terminated, [100]);
      expect(
        harness.out.toString(),
        contains('Time is up: closed 1 game process(es).'),
      );
      expect(harness.out.toString(), contains('Used: 1:00.'));
    });
  });
}
