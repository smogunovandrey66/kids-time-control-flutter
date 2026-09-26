import 'package:ktc_core/ktc_core.dart';

/// Access to operating system processes. The Windows implementation uses
/// WinAPI; tests use an in-memory fake.
abstract interface class ProcessControl {
  /// Processes whose executable path could be read. System processes that
  /// cannot be opened without extra privileges are skipped.
  List<ProcessInfo> list();

  bool terminate(int pid);

  bool suspend(int pid);

  bool resume(int pid);
}
