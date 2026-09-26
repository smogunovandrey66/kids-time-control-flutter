/// PIN hashing: PBKDF2-HMAC-SHA256.
///
/// Stored format, shared by the PC and the parent app:
/// `pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>`.
/// The parent app hashes a new PIN; the PC only verifies, fully offline.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const defaultPinIterations = 100000;
const _prefix = 'pbkdf2-sha256';
const _hashLength = 32;
const _saltLength = 16;

/// PBKDF2 with HMAC-SHA256 (RFC 8018).
Uint8List pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  final hmac = Hmac(sha256, password);
  final result = Uint8List(keyLength);
  var offset = 0;
  for (var block = 1; offset < keyLength; block++) {
    // U1 = HMAC(password, salt || INT_32_BE(block))
    var u = hmac.convert([
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    final count = min(t.length, keyLength - offset);
    result.setRange(offset, offset + count, t);
    offset += count;
  }
  return result;
}

/// Hashes [pin] with an explicit [salt] (tests, cross-platform checks).
String hashPinWithSalt(String pin, List<int> salt, {required int iterations}) {
  final hash = pbkdf2Sha256(utf8.encode(pin), salt, iterations, _hashLength);
  return '$_prefix\$$iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
}

/// Hashes [pin] with a fresh cryptographically random salt.
String hashPin(
  String pin, {
  int iterations = defaultPinIterations,
  Random? random,
}) {
  final rng = random ?? Random.secure();
  final salt = List<int>.generate(_saltLength, (_) => rng.nextInt(256));
  return hashPinWithSalt(pin, salt, iterations: iterations);
}

/// `false` for a wrong PIN or a malformed [storedHash].
bool verifyPin(String pin, String storedHash) {
  final parts = storedHash.split(r'$');
  if (parts.length != 4 || parts[0] != _prefix) return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;

  final List<int> salt;
  final List<int> expected;
  try {
    salt = base64.decode(parts[2]);
    expected = base64.decode(parts[3]);
  } on FormatException {
    return false;
  }
  if (expected.isEmpty) return false;

  final actual = pbkdf2Sha256(
    utf8.encode(pin),
    salt,
    iterations,
    expected.length,
  );
  return _constantTimeEquals(actual, expected);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
