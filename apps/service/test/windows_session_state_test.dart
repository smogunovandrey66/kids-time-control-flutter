@TestOn('windows')
library;

import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

/// Runs against the real API on Windows (CI: windows-latest).
void main() {
  test('reads the console session and its lock state', () {
    final state = WindowsSessionState();
    expect(state.activeSessionId(), isNonNegative);
    expect(state.isLocked, returnsNormally);
    // ignore: avoid_print
    print(
      'console session ${state.activeSessionId()}, locked: ${state.isLocked()}',
    );
  });
}
