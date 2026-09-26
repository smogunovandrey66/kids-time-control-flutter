import 'dart:convert';

import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('PBKDF2 matches the RFC 7914 reference vector', () {
    // PBKDF2-HMAC-SHA256("passwd", "salt", c = 1), first 32 bytes.
    expect(
      hex(pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 32)),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
    );
  });

  test('hash format is stable across platforms', () {
    // Same value as shared/examples/child.json, produced by Python's hashlib.pbkdf2_hmac.
    const stored =
        r'pbkdf2-sha256$10000$a3RjLXRlc3Qtc2FsdA==$LxrtrmK164FUMoBkx/0kVzkUUXAlTlK3MCyFqTb7Tsc=';

    expect(
      hashPinWithSalt('1234', utf8.encode('ktc-test-salt'), iterations: 10000),
      stored,
    );
    expect(verifyPin('1234', stored), isTrue);
    expect(verifyPin('1235', stored), isFalse);
  });

  test('hash then verify', () {
    final hash = hashPin('0000', iterations: 1000);

    expect(hash, startsWith(r'pbkdf2-sha256$1000$'));
    expect(verifyPin('0000', hash), isTrue);
    expect(verifyPin('0001', hash), isFalse);
  });

  test('salt is random', () {
    expect(
      hashPin('1234', iterations: 1000),
      isNot(hashPin('1234', iterations: 1000)),
    );
  });

  test('rejects malformed hashes', () {
    for (final stored in [
      '',
      'plain-text',
      r'md5$1$AAAA$AAAA',
      r'pbkdf2-sha256$abc$AAAA$AAAA',
      r'pbkdf2-sha256$1000$AAAA$',
      r'pbkdf2-sha256$1000$not base64!$AAAA',
    ]) {
      expect(verifyPin('1234', stored), isFalse, reason: stored);
    }
  });
}
