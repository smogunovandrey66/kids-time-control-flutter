@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ktc_agent/src/windows.dart';

/// Runs against the real API on Windows (CI: windows-latest, as an administrator).
void main() {
  test('knows the session and that the CI user is an administrator', () {
    expect(currentSessionId(), isNonNegative);
    expect(currentUserIsAdmin(), isTrue);
  });

  test('one agent per session', () {
    expect(claimSingleInstance(), isTrue);
    expect(claimSingleInstance(), isFalse);
  });
}
