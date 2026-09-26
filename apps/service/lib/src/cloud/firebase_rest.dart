import 'dart:async';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firestore_codec.dart';

/// Where the Firebase REST APIs live. Tests point it at the local emulators.
final class FirebaseEndpoints {
  const FirebaseEndpoints({
    required this.apiKey,
    required this.projectId,
    this.authBase = 'https://identitytoolkit.googleapis.com',
    this.tokenBase = 'https://securetoken.googleapis.com',
    this.firestoreBase = 'https://firestore.googleapis.com',
  });

  /// Firebase Local Emulator Suite (auth on 9099, Firestore on 8080).
  const FirebaseEndpoints.emulator({
    required this.projectId,
    String host = '127.0.0.1',
  }) : apiKey = 'emulator',
       authBase = 'http://$host:9099/identitytoolkit.googleapis.com',
       tokenBase = 'http://$host:9099/securetoken.googleapis.com',
       firestoreBase = 'http://$host:8080';

  final String apiKey;
  final String projectId;
  final String authBase;
  final String tokenBase;
  final String firestoreBase;

  String get documentsPath =>
      'projects/$projectId/databases/(default)/documents';
}

final class FirebaseRestException implements Exception {
  FirebaseRestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get isPermissionDenied => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'FirebaseRestException($statusCode): $body';
}

/// Anonymous Firebase Auth session of the PC.
final class AuthSession {
  AuthSession({required this.uid, required this.refreshToken});

  final String uid;
  String refreshToken;
  String? _idToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get needsRefresh =>
      _idToken == null || DateTime.now().isAfter(_expiresAt);
}

/// Minimal REST client for Firebase Auth (anonymous) and Cloud Firestore.
final class FirebaseRestClient {
  /// Every request fails with a [TimeoutException] after [timeout], so a
  /// hanging connection does not stall synchronization forever.
  FirebaseRestClient(
    this.endpoints, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) : _http = _TimeoutClient(client ?? http.Client(), timeout);

  final FirebaseEndpoints endpoints;
  final http.Client _http;

  /// Creates a new anonymous user.
  Future<AuthSession> signInAnonymously() async {
    final json = await _post(
      Uri.parse(
        '${endpoints.authBase}/v1/accounts:signUp?key=${endpoints.apiKey}',
      ),
      body: jsonEncode({'returnSecureToken': true}),
      contentType: 'application/json',
    );
    return AuthSession(
        uid: json['localId']! as String,
        refreshToken: json['refreshToken']! as String,
      )
      .._idToken = json['idToken']! as String
      .._expiresAt = _expiry(json['expiresIn']);
  }

  /// Email/password sign-up. Used by tests to act as a parent on the emulator.
  Future<AuthSession> signUpWithEmail(String email, String password) async {
    final json = await _post(
      Uri.parse(
        '${endpoints.authBase}/v1/accounts:signUp?key=${endpoints.apiKey}',
      ),
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
      contentType: 'application/json',
    );
    return AuthSession(
        uid: json['localId']! as String,
        refreshToken: json['refreshToken']! as String,
      )
      .._idToken = json['idToken']! as String
      .._expiresAt = _expiry(json['expiresIn']);
  }

  Future<String> idToken(AuthSession session) async {
    if (session.needsRefresh) {
      final json = await _post(
        Uri.parse('${endpoints.tokenBase}/v1/token?key=${endpoints.apiKey}'),
        body:
            'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(session.refreshToken)}',
        contentType: 'application/x-www-form-urlencoded',
      );
      session
        ..refreshToken = json['refresh_token']! as String
        .._idToken = json['id_token']! as String
        .._expiresAt = _expiry(json['expires_in']);
    }
    return session._idToken!;
  }

  /// Creates `collection/{id}`; fields listed in [serverTimestamps] are set to the request time.
  Future<void> createDocument(
    AuthSession session,
    String collection,
    String id,
    Map<String, Object?> fields, {
    List<String> serverTimestamps = const [],
  }) async {
    final name = '${endpoints.documentsPath}/$collection/$id';
    await _authorizedPost(session, ':commit', {
      'writes': [
        {
          'update': {'name': name, 'fields': encodeFields(fields)},
          'updateTransforms': [
            for (final field in serverTimestamps)
              {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
          ],
          'currentDocument': {'exists': false},
        },
      ],
    });
  }

  /// Creates or replaces the document at [path] (e.g. `families/f1/usage/ivan_2026-09-28`).
  Future<void> setDocument(
    AuthSession session,
    String path,
    Map<String, Object?> fields,
  ) async {
    final response = await _http.patch(
      Uri.parse(
        '${endpoints.firestoreBase}/v1/${endpoints.documentsPath}/$path',
      ),
      headers: await _headers(session),
      body: jsonEncode({'fields': encodeFields(fields)}),
    );
    _check(response);
  }

  /// Fields of the document at [path], or `null` if it does not exist.
  Future<Map<String, Object?>?> getDocument(
    AuthSession session,
    String path,
  ) async {
    final response = await _http.get(
      Uri.parse(
        '${endpoints.firestoreBase}/v1/${endpoints.documentsPath}/$path',
      ),
      headers: await _headers(session),
    );
    if (response.statusCode == 404) return null;
    final json = _check(response);
    return decodeFields(json['fields'] as Map<String, Object?>? ?? const {});
  }

  Future<void> deleteDocument(AuthSession session, String path) async {
    final response = await _http.delete(
      Uri.parse(
        '${endpoints.firestoreBase}/v1/${endpoints.documentsPath}/$path',
      ),
      headers: await _headers(session),
    );
    _check(response);
  }

  /// Documents of a collection: id → fields.
  Future<Map<String, Map<String, Object?>>> listDocuments(
    AuthSession session,
    String path,
  ) async {
    final result = <String, Map<String, Object?>>{};
    String? pageToken;
    do {
      final uri = Uri.parse(
        '${endpoints.firestoreBase}/v1/${endpoints.documentsPath}/$path',
      ).replace(queryParameters: {'pageSize': '300', 'pageToken': ?pageToken});
      final response = await _http.get(uri, headers: await _headers(session));
      final json = _check(response);
      for (final doc in json['documents'] as List<Object?>? ?? const []) {
        final document = doc! as Map<String, Object?>;
        result[documentId(document['name']! as String)] = decodeFields(
          document['fields'] as Map<String, Object?>? ?? const {},
        );
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
    return result;
  }

  /// Ids of top-level [collection] documents where [field] (an array) contains [value].
  Future<List<String>> queryArrayContains(
    AuthSession session,
    String collection,
    String field,
    String value,
  ) async {
    final response = await _authorizedPost(session, ':runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': field},
            'op': 'ARRAY_CONTAINS',
            'value': encodeValue(value),
          },
        },
      },
    });
    return [
      for (final row in response as List<Object?>)
        if ((row! as Map<String, Object?>)['document']
            case final Map<String, Object?> document)
          documentId(document['name']! as String),
    ];
  }

  void close() => _http.close();

  Future<Object?> _authorizedPost(
    AuthSession session,
    String method,
    Object body,
  ) async {
    final response = await _http.post(
      Uri.parse(
        '${endpoints.firestoreBase}/v1/${endpoints.documentsPath}$method',
      ),
      headers: await _headers(session),
      body: jsonEncode(body),
    );
    _check(response);
    return jsonDecode(response.body);
  }

  Future<Map<String, String>> _headers(AuthSession session) async => {
    'Authorization': 'Bearer ${await idToken(session)}',
    'Content-Type': 'application/json',
  };

  Future<Map<String, Object?>> _post(
    Uri uri, {
    required String body,
    required String contentType,
  }) async {
    final response = await _http.post(
      uri,
      headers: {'Content-Type': contentType},
      body: body,
    );
    return _check(response);
  }

  Map<String, Object?> _check(http.Response response) {
    if (response.statusCode >= 300) {
      throw FirebaseRestException(response.statusCode, response.body);
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    return decoded is Map<String, Object?> ? decoded : const {};
  }

  static DateTime _expiry(Object? expiresIn) => DateTime.now().add(
    // Refresh a minute early.
    Duration(seconds: int.parse(expiresIn! as String) - 60),
  );
}

final class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request).timeout(_timeout);
    final body = await response.stream.toBytes().timeout(_timeout);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(body),
      response.statusCode,
      contentLength: body.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
