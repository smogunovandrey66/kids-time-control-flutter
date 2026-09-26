// End-to-end test of the PC <-> cloud protocol against the Firebase emulators
// with the real security rules. Runs only when the emulators are up:
//   cd firebase && npx firebase emulators:exec --only auth,firestore \
//     "cd ../apps/service && dart test test/cloud_emulator_test.dart"
@Tags(['emulator'])
library;

import 'dart:io';

import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

void main() {
  final emulatorRunning = Platform.environment.containsKey(
    'FIRESTORE_EMULATOR_HOST',
  );
  const endpoints = FirebaseEndpoints.emulator(
    projectId: 'demo-kids-time-control',
  );

  test(
    'pair, pull config, push usage and status',
    skip: emulatorRunning ? false : 'Firebase emulators are not running',
    () async {
      final client = FirebaseRestClient(endpoints);
      addTearDown(client.close);

      // The parent (non-anonymous) creates a family with a child and a game.
      final parent = await client.signUpWithEmail(
        'parent${DateTime.now().microsecondsSinceEpoch}@example.com',
        'password123',
      );
      final familyId = 'family-${parent.uid}';
      await client.setDocument(parent, 'families/$familyId', {
        'name': 'Test',
        'parents': [parent.uid],
        'deviceUids': <String>[],
        'timeZone': 'Europe/Moscow',
      });
      await client.setDocument(parent, 'families/$familyId/children/ivan', {
        'name': 'Ivan',
        'pinHash': hashPin('1234', iterations: 1000),
        'limits': {'weekdaySeconds': 3600, 'weekendSeconds': 7200},
        'archived': false,
      });
      await client.setDocument(parent, 'families/$familyId/apps/minecraft', {
        'name': 'Minecraft',
        'match': {'exeName': 'javaw.exe', 'commandLineContains': 'minecraft'},
        'archived': false,
      });

      // The PC signs in anonymously and publishes a pairing code.
      final pc = CloudSync(
        client,
        CloudState(
          apiKey: 'emulator',
          projectId: endpoints.projectId,
          deviceName: 'Home PC',
        ),
      );
      final code = await pc.startPairing();
      expect(await pc.findFamily(), isNull);

      // An unpaired PC cannot read the family.
      await expectLater(
        pc.pullConfig,
        throwsA(isA<StateError>()),
        reason: 'no family id yet',
      );

      // The parent redeems the code, exactly like the parent app does.
      final request = await client.getDocument(parent, 'pairingRequests/$code');
      expect(request!['deviceName'], 'Home PC');
      await client.setDocument(parent, 'families/$familyId', {
        'name': 'Test',
        'parents': [parent.uid],
        'deviceUids': [request['uid']],
        'timeZone': 'Europe/Moscow',
      });
      await client.deleteDocument(parent, 'pairingRequests/$code');

      // The PC finds its family and syncs.
      expect(await pc.findFamily(), familyId);
      final config = await pc.pullConfig();
      expect(config.child('ivan')!.name, 'Ivan');
      expect(verifyPin('1234', config.child('ivan')!.pinHash), isTrue);
      expect(config.apps.single.exeName, 'javaw.exe');

      await pc.pushUsage([
        const DailyUsage(
          childId: 'ivan',
          date: '2026-09-28',
          totalSeconds: 600,
          apps: {'minecraft': 600},
        ),
      ]);
      await pc.reportStatus(appVersion: appVersion, activeChildId: 'ivan');

      final usage = await client.getDocument(
        parent,
        'families/$familyId/usage/ivan_2026-09-28',
      );
      expect(usage!['totalSeconds'], 600);
      final device = await client.getDocument(
        parent,
        'families/$familyId/devices/${pc.state.uid}',
      );
      expect(device!['activeChildId'], 'ivan');

      // The PC must not be able to raise a limit.
      final session = await pc.session();
      await expectLater(
        client.setDocument(session, 'families/$familyId/children/ivan', {
          'name': 'Ivan',
          'pinHash': hashPin('1234', iterations: 1000),
          'limits': {'weekdaySeconds': 86400, 'weekendSeconds': 86400},
          'archived': false,
        }),
        throwsA(
          isA<FirebaseRestException>().having(
            (e) => e.isPermissionDenied,
            'denied',
            isTrue,
          ),
        ),
      );
    },
  );
}
