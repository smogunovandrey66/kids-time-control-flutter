import 'dart:math';

import 'package:ktc_core/ktc_core.dart';

import 'firebase_rest.dart';

/// State of the PC in the cloud, stored in `cloud.json`.
final class CloudState {
  CloudState({
    required this.apiKey,
    required this.projectId,
    required this.deviceName,
    this.uid,
    this.refreshToken,
    this.familyId,
  });

  factory CloudState.fromJson(Map<String, Object?> json) => CloudState(
    apiKey: json['apiKey']! as String,
    projectId: json['projectId']! as String,
    deviceName: json['deviceName'] as String? ?? 'PC',
    uid: json['uid'] as String?,
    refreshToken: json['refreshToken'] as String?,
    familyId: json['familyId'] as String?,
  );

  final String apiKey;
  final String projectId;
  final String deviceName;
  String? uid;
  String? refreshToken;
  String? familyId;

  Map<String, Object?> toJson() => {
    'apiKey': apiKey,
    'projectId': projectId,
    'deviceName': deviceName,
    'uid': uid,
    'refreshToken': refreshToken,
    'familyId': familyId,
  };
}

/// What the PC does in the cloud. All calls are allowed by `firebase/firestore.rules`
/// for a paired device and nothing else.
final class CloudSync {
  CloudSync(this.client, this.state, {Random? random}) : _random = random;

  final FirebaseRestClient client;
  final CloudState state;
  final Random? _random;
  AuthSession? _session;

  Future<AuthSession> session() async {
    if (_session case final session?) return session;
    if (state.uid != null && state.refreshToken != null) {
      return _session = AuthSession(
        uid: state.uid!,
        refreshToken: state.refreshToken!,
      );
    }
    final session = await client.signInAnonymously();
    state
      ..uid = session.uid
      ..refreshToken = session.refreshToken;
    return _session = session;
  }

  /// Publishes a new pairing code for the parent's app.
  Future<String> startPairing() async {
    final session = await this.session();
    for (var attempt = 0; ; attempt++) {
      final code = PairingCode.generate(_random);
      try {
        await client.createDocument(
          session,
          'pairingRequests',
          code,
          {'uid': session.uid, 'deviceName': state.deviceName},
          serverTimestamps: const ['createdAt'],
        );
        return code;
      } on FirebaseRestException catch (error) {
        // 409: the code is taken (astronomically unlikely); try another one.
        if (error.statusCode != 409 || attempt >= 3) rethrow;
      }
    }
  }

  /// The family this PC was added to, or `null` while the parent has not redeemed the code.
  Future<String?> findFamily() async {
    final session = await this.session();
    final ids = await client.queryArrayContains(
      session,
      'families',
      'deviceUids',
      session.uid,
    );
    if (ids.isNotEmpty) state.familyId = ids.first;
    return state.familyId = ids.firstOrNull;
  }

  String get _familyPath =>
      'families/${state.familyId ?? (throw StateError('Not paired'))}';

  /// Children and games configured by the parent.
  Future<LocalConfig> pullConfig() async {
    final session = await this.session();
    final children = await client.listDocuments(
      session,
      '$_familyPath/children',
    );
    final apps = await client.listDocuments(session, '$_familyPath/apps');
    return LocalConfig.fromJson({'children': children, 'apps': apps});
  }

  Future<void> pushUsage(Iterable<DailyUsage> usage) async {
    final session = await this.session();
    for (final record in usage) {
      await client.setDocument(
        session,
        '$_familyPath/usage/${DailyUsage.documentId(record.childId, record.date)}',
        record.toJson(),
      );
    }
  }

  Future<void> reportStatus({
    required String appVersion,
    String? activeChildId,
    DateTime? now,
  }) async {
    final session = await this.session();
    await client.setDocument(
      session,
      '$_familyPath/devices/${session.uid}',
      Device(
        id: session.uid,
        name: state.deviceName,
        appVersion: appVersion,
        lastSeen: now ?? DateTime.now(),
        activeChildId: activeChildId,
      ).toJson(),
    );
  }
}
