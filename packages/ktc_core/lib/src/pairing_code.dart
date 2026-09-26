import 'dart:math';

/// Pairing codes: 8 characters without look-alikes (no 0/O, 1/I),
/// shown as `ABCD-2345`. Must match `pairingRequests/{code}` in the rules.
abstract final class PairingCode {
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 8;
  static final _valid = RegExp('^[A-Z2-9]{$length}\$');

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
      ),
    );
  }

  /// Accepts user input like `k7qm-4xp2` or `K7QM 4XP2`; `null` if it is not a code.
  static String? normalize(String input) {
    final code = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return _valid.hasMatch(code) ? code : null;
  }

  /// `ABCD2345` → `ABCD-2345`.
  static String format(String code) => code.length == length
      ? '${code.substring(0, 4)}-${code.substring(4)}'
      : code;
}
