import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ktc_core/ktc_core.dart';

import 'repositories.dart';

final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null || user.isAnonymous
        ? null
        : AppUser(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
          ),
  );

  @override
  Future<void> signInWithGoogle() async {
    // The browser IDP flow (signInWithProvider) breaks on Android when the
    // browser partitions storage, so use the native Google account picker.
    if (Platform.isAndroid) {
      final google = GoogleSignIn(scopes: ['email']);
      final account = await google.signIn();
      if (account == null) return; // cancelled
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } else {
      await _auth.signInWithProvider(GoogleAuthProvider());
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

final class FirestoreFamilyRepository implements FamilyRepository {
  FirestoreFamilyRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');

  CollectionReference<Map<String, dynamic>> _sub(
    String familyId,
    String name,
  ) => _families.doc(familyId).collection(name);

  @override
  Stream<Family?> watchFamilyOf(String parentUid) => _families
      .where('parents', arrayContains: parentUid)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        return Family.fromJson(doc.id, doc.data());
      });

  @override
  Future<void> createFamily({
    required String parentUid,
    required String name,
    required String timeZone,
  }) => _families.add({
    'name': name,
    'parents': [parentUid],
    'deviceUids': <String>[],
    'timeZone': timeZone,
  });

  @override
  String newId() => _families.doc().id;

  @override
  Stream<List<Child>> watchChildren(String familyId) =>
      _sub(familyId, 'children').snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs) Child.fromJson(doc.id, doc.data()),
        ],
      );

  @override
  Future<void> saveChild(String familyId, Child child) =>
      _sub(familyId, 'children').doc(child.id).set(child.toJson());

  @override
  Stream<List<AppRule>> watchApps(String familyId) =>
      _sub(familyId, 'apps').snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs) AppRule.fromJson(doc.id, doc.data()),
        ],
      );

  @override
  Future<void> saveApp(String familyId, AppRule app) =>
      _sub(familyId, 'apps').doc(app.id).set(app.toJson());

  @override
  Stream<List<Device>> watchDevices(String familyId) =>
      _sub(familyId, 'devices').snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs) Device.fromJson(doc.id, doc.data()),
        ],
      );

  @override
  Future<PairingResult> pairDevice(Family family, String code) async {
    final request = _db.collection('pairingRequests').doc(code);
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await request.get();
    } on FirebaseException catch (error) {
      // The rules deny reading expired codes.
      if (error.code == 'permission-denied') return PairingResult.notFound;
      rethrow;
    }
    final data = snapshot.data();
    if (data == null) return PairingResult.notFound;

    final deviceUid = data['uid'] as String;
    final batch = _db.batch()
      ..update(_families.doc(family.id), {
        'deviceUids': FieldValue.arrayUnion([deviceUid]),
      })
      ..set(_sub(family.id, 'devices').doc(deviceUid), {
        'name': data['deviceName'] as String? ?? 'PC',
        'appVersion': '',
        'lastSeen': '',
      })
      ..delete(request);
    await batch.commit();
    return PairingResult.paired;
  }

  @override
  Future<void> removeDevice(Family family, String deviceUid) async {
    final batch = _db.batch()
      ..update(_families.doc(family.id), {
        'deviceUids': FieldValue.arrayRemove([deviceUid]),
      })
      ..delete(_sub(family.id, 'devices').doc(deviceUid));
    await batch.commit();
  }

  @override
  Stream<List<DailyUsage>> watchUsage(
    String familyId, {
    required String fromDate,
    required String toDate,
  }) => _sub(familyId, 'usage')
      .where('date', isGreaterThanOrEqualTo: fromDate)
      .where('date', isLessThanOrEqualTo: toDate)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs) DailyUsage.fromJson(doc.data()),
        ],
      );
}
