import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_parent/data/repositories.dart';

import 'fakes.dart';

void main() {
  testWidgets('sign in, create a family, land on Today', (tester) async {
    final families = FakeFamilyRepository();
    await tester.pumpParentApp(auth: FakeAuthRepository(), families: families);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Create your family'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Smirnovs');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(families.family?.name, 'Smirnovs');
    expect(families.family?.timeZone, 'Europe/Moscow');
    expect(find.text('Add a child on the Children tab.'), findsOneWidget);
  });

  group('signed in with a family', () {
    late FakeFamilyRepository families;

    setUp(() {
      families = FakeFamilyRepository()
        ..family = testFamily()
        ..children['ivan'] = testChild()
        ..usage.add(
          const DailyUsage(
            childId: 'ivan',
            date: '2026-09-28',
            totalSeconds: 1800,
          ),
        );
    });

    Future<void> pump(WidgetTester tester) => tester.pumpParentApp(
      auth: FakeAuthRepository(user: const AppUser(uid: 'parent')),
      families: families,
    );

    testWidgets('Today shows usage and adds extra time', (tester) async {
      await pump(tester);

      expect(find.text('Ivan'), findsOneWidget);
      expect(find.text('0:30 of 1:00'), findsOneWidget);
      expect(find.text('0:30 left'), findsOneWidget);

      await tester.tap(find.text('+15 min'));
      await tester.pumpAndSettle();

      expect(families.children['ivan']!.bonus!.seconds, 15 * 60);
      expect(find.text('0:30 of 1:15'), findsOneWidget);
    });

    testWidgets('adds a child with a hashed PIN', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Children'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add child'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Set a PIN'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Marina');
      await tester.enterText(
        find.widgetWithText(TextField, 'PIN (4-6 digits)'),
        '5678',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final marina = families.children.values.firstWhere(
        (child) => child.name == 'Marina',
      );
      expect(
        marina.pinHash,
        endsWith(r'$5678'),
        reason: 'fake hasher in tests',
      );
      expect(marina.limits.weekdaySeconds, 3600);
      expect(find.text('Marina'), findsOneWidget);
    });

    testWidgets('adds a game rule', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add game'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Roblox');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Fill in at least one of the fields'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Executable name, e.g. RobloxPlayerBeta.exe',
        ),
        'RobloxPlayerBeta.exe',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(families.apps.values.single.exeName, 'RobloxPlayerBeta.exe');
    });

    testWidgets('pairs a computer by code', (tester) async {
      families.pairingRequests['K7QM4XP2'] = 'pc-uid';
      await pump(tester);
      await tester.tap(find.text('Computers'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pair computer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pairingCode')), 'k7qm');
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      expect(find.text('A code has 8 characters'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pairingCode')), 'wrong-cod');
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('pairingCode')), 'k7qm-4xp2');
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      expect(find.text('Computer paired'), findsOneWidget);
      expect(families.devices.keys, ['pc-uid']);
      expect(find.text('Has not connected yet'), findsOneWidget);
    });
  });
}
