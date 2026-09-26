import 'package:ktc_core/ktc_core.dart';

/// Signed-in parent.
final class AppUser {
  const AppUser({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;
}

abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<void> signInWithGoogle();

  Future<void> signOut();
}

enum PairingResult { paired, notFound }

/// Everything the app reads and writes in Firestore. The screens depend only
/// on this interface; tests use an in-memory implementation.
abstract interface class FamilyRepository {
  Stream<Family?> watchFamilyOf(String parentUid);

  Future<void> createFamily({
    required String parentUid,
    required String name,
    required String timeZone,
  });

  /// A new unique document id for children and apps.
  String newId();

  Stream<List<Child>> watchChildren(String familyId);

  Future<void> saveChild(String familyId, Child child);

  Stream<List<AppRule>> watchApps(String familyId);

  Future<void> saveApp(String familyId, AppRule app);

  Stream<List<Device>> watchDevices(String familyId);

  /// Redeems a pairing code shown on the PC.
  Future<PairingResult> pairDevice(Family family, String code);

  Future<void> removeDevice(Family family, String deviceUid);

  /// Usage of all children for dates in `[fromDate, toDate]` (`YYYY-MM-DD`).
  Stream<List<DailyUsage>> watchUsage(
    String familyId, {
    required String fromDate,
    required String toDate,
  });
}
