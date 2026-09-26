import 'package:ktc_core/ktc_core.dart';

import 'login_broker.dart';

/// Login in the console, for `ktc service --console` (development and testing
/// before the tray agent exists).
final class ConsoleLoginBroker implements LoginBroker {
  ConsoleLoginBroker({required this.out, required this.readLine});

  final StringSink out;
  final String? Function() readLine;

  @override
  Future<LoginAnswer?> askLogin({
    required List<Child> children,
    required String appName,
    LoginError? previousError,
  }) async {
    if (previousError != null) {
      out.writeln('Login failed: ${previousError.name}.');
    }
    out.writeln('Who is playing $appName?');
    for (final (index, child) in children.indexed) {
      out.writeln('  ${index + 1}. ${child.name}');
    }
    out.write('Number (empty to cancel): ');
    final choice = int.tryParse(readLine()?.trim() ?? '');
    if (choice == null || choice < 1 || choice > children.length) return null;
    out.write('PIN: ');
    final pin = readLine()?.trim();
    if (pin == null || pin.isEmpty) return null;
    return (childId: children[choice - 1].id, pin: pin);
  }

  @override
  void notify(Notice notice) => out.writeln('>>> $notice');
}
