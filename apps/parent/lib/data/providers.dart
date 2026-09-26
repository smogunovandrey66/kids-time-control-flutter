import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ktc_core/ktc_core.dart';

import '../logic/child_form.dart';
import 'repositories.dart';

/// Overridden in `main.dart` with Firebase implementations and in tests with fakes.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('authRepositoryProvider must be overridden'),
);

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) =>
      throw UnimplementedError('familyRepositoryProvider must be overridden'),
);

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Hashes a new PIN (slow on purpose: PBKDF2); overridden in tests.
final pinHasherProvider = Provider<Future<String> Function(String pin)>(
  (ref) => hashPinInBackground,
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final familyProvider = StreamProvider<Family?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchFamilyOf(user.uid);
});

/// The family is required below the home screen.
Family requireFamily(Ref ref) =>
    ref.watch(familyProvider).value ?? (throw StateError('No family loaded'));

final childrenProvider = StreamProvider<List<Child>>((ref) {
  final family = requireFamily(ref);
  return ref
      .watch(familyRepositoryProvider)
      .watchChildren(family.id)
      .map(
        (children) =>
            children.where((child) => !child.archived).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

final appsProvider = StreamProvider<List<AppRule>>((ref) {
  final family = requireFamily(ref);
  return ref
      .watch(familyRepositoryProvider)
      .watchApps(family.id)
      .map(
        (apps) =>
            apps.where((app) => !app.archived).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

final devicesProvider = StreamProvider<List<Device>>((ref) {
  final family = requireFamily(ref);
  return ref.watch(familyRepositoryProvider).watchDevices(family.id);
});

/// Usage for the last 7 days (including today) of all children.
final weekUsageProvider = StreamProvider<List<DailyUsage>>((ref) {
  final family = requireFamily(ref);
  final today = ref.watch(clockProvider)();
  return ref
      .watch(familyRepositoryProvider)
      .watchUsage(
        family.id,
        fromDate: dateKey(today.subtract(const Duration(days: 6))),
        toDate: dateKey(today),
      );
});
