import 'dart:math';

import 'package:ktc_core/ktc_core.dart';
import 'package:test/test.dart';

void main() {
  test('generated codes are valid and avoid look-alike characters', () {
    final random = Random(1);
    for (var i = 0; i < 100; i++) {
      final code = PairingCode.generate(random);
      expect(PairingCode.normalize(code), code);
      expect(code, isNot(matches('[01OI]')));
    }
  });

  test('normalizes user input', () {
    expect(PairingCode.normalize('k7qm-4xp2'), 'K7QM4XP2');
    expect(PairingCode.normalize(' K7QM 4XP2 '), 'K7QM4XP2');
    expect(PairingCode.normalize('K7QM'), isNull);
    expect(
      PairingCode.normalize('K7QM-4XP0'),
      isNull,
      reason: '0 is not in the alphabet',
    );
  });

  test('formats for display', () {
    expect(PairingCode.format('K7QM4XP2'), 'K7QM-4XP2');
  });
}
