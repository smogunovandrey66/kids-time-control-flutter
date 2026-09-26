import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktc_core/ktc_core.dart';
import 'package:ktc_parent/app.dart';
import 'package:ktc_parent/data/providers.dart';
import 'package:ktc_parent/data/repositories.dart';
import 'package:ktc_parent/features/create_family_page.dart';

/// Monday, so the weekday limit applies.
final now = DateTime(2026, 9, 28, 18);

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : _user = user;

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    _user = const AppUser(uid: 'parent', displayName: 'Parent');
    _changes.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }
}

/// In-memory Firestore replacement with the same behavior the screens rely on.
final class FakeFamilyRepository implements FamilyRepository {
  Family? family;
  final children = <String, Child>{};
  final apps = <String, AppRule>{};
  final devices = <String, Device>{};
  final usage = <DailyUsage>[];

  /// Pairing codes created by PCs: code → device uid.
  final pairingRequests = <String, String>{};
  var _ids = 0;
  final _changed = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  void _notify() => _changed.add(null);

  @override
  Stream<Family?> watchFamilyOf(String parentUid) => _watch(
    () => family?.parents.contains(parentUid) ?? false ? family : null,
  );

  @override
  Future<void> createFamily({
    required String parentUid,
    required String name,
    required String timeZone,
  }) async {
    family = Family(
      id: 'f1',
      name: name,
      parents: [parentUid],
      deviceUids: const [],
      timeZone: timeZone,
    );
    _notify();
  }

  @override
  String newId() => 'id${_ids++}';

  @override
  Stream<List<Child>> watchChildren(String familyId) =>
      _watch(() => children.values.toList());

  @override
  Future<void> saveChild(String familyId, Child child) async {
    children[child.id] = child;
    _notify();
  }

  @override
  Stream<List<AppRule>> watchApps(String familyId) =>
      _watch(() => apps.values.toList());

  @override
  Future<void> saveApp(String familyId, AppRule app) async {
    apps[app.id] = app;
    _notify();
  }

  @override
  Stream<List<Device>> watchDevices(String familyId) =>
      _watch(() => devices.values.toList());

  @override
  Future<PairingResult> pairDevice(Family family, String code) async {
    final uid = pairingRequests.remove(code);
    if (uid == null) return PairingResult.notFound;
    devices[uid] = Device(
      id: uid,
      name: 'Home PC',
      appVersion: '',
      lastSeen: null,
    );
    _notify();
    return PairingResult.paired;
  }

  @override
  Future<void> removeDevice(Family family, String deviceUid) async {
    devices.remove(deviceUid);
    _notify();
  }

  @override
  Stream<List<DailyUsage>> watchUsage(
    String familyId, {
    required String fromDate,
    required String toDate,
  }) => _watch(
    () => [
      for (final record in usage)
        if (record.date.compareTo(fromDate) >= 0 &&
            record.date.compareTo(toDate) <= 0)
          record,
    ],
  );
}

Child testChild({String id = 'ivan', String name = 'Ivan', Bonus? bonus}) =>
    Child(
      id: id,
      name: name,
      pinHash: 'pbkdf2-sha256\$1\$AA==\$AA==',
      limits: const Limits(weekdaySeconds: 3600, weekendSeconds: 7200),
      bonus: bonus,
    );

Family testFamily() => const Family(
  id: 'f1',
  name: 'Family',
  parents: ['parent'],
  deviceUids: [],
  timeZone: 'Europe/Moscow',
);

extension PumpApp on WidgetTester {
  Future<void> pumpParentApp({
    required FakeAuthRepository auth,
    required FakeFamilyRepository families,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          familyRepositoryProvider.overrideWithValue(families),
          clockProvider.overrideWithValue(() => now),
          pinHasherProvider.overrideWithValue(
            (pin) async => 'pbkdf2-sha256\$1\$AA==\$$pin',
          ),
          timeZoneProvider.overrideWith((ref) async => 'Europe/Moscow'),
        ],
        child: const ParentApp(),
      ),
    );
    await pumpAndSettle();
  }
}
