import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  test('a hanging network does not pause the ticks', () async {
    var now = Duration.zero;
    final requests = <Uri>[];
    final hang = Completer<http.Response>();
    final processes = FakeProcessControl([browser]);
    final dir = DataDir(Directory.systemTemp.createTempSync('ktc_runner').path);
    final engine = ServiceEngine(
      processes: processes,
      broker: NoAgentBroker((_) {}),
      dir: dir,
      wallClock: () => DateTime(2026, 9, 28, 18).add(now),
      monotonicNow: () => now,
    );
    final cloud = CloudSync(
      FirebaseRestClient(
        const FirebaseEndpoints(apiKey: 'key', projectId: 'demo'),
        client: MockClient((request) {
          requests.add(request.url);
          return hang.future;
        }),
        timeout: const Duration(days: 1),
      ),
      CloudState(
        apiKey: 'key',
        projectId: 'demo',
        deviceName: 'PC',
        uid: 'pc',
        refreshToken: 'token',
        familyId: 'f1',
      ),
    );
    late ServiceRunner runner;
    var ticks = 0;
    runner = ServiceRunner(
      engine: engine,
      dir: dir,
      cloud: cloud,
      monotonicNow: () => now,
      wallClock: () => DateTime(2026, 9, 28, 18).add(now),
      sleep: (duration) async {
        now += duration;
        if (++ticks == 100) runner.stop();
        await pumpEventQueue();
      },
    );

    await runner.run();

    expect(processes.listCalls, 100);
    expect(requests, hasLength(1), reason: 'no second sync while one hangs');
  });

  test('requests time out', () async {
    final client = FirebaseRestClient(
      const FirebaseEndpoints(apiKey: 'key', projectId: 'demo'),
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      client.signInAnonymously(),
      throwsA(isA<TimeoutException>()),
    );
  });
}
