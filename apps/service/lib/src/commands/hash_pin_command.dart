import 'package:args/command_runner.dart';
import 'package:ktc_core/ktc_core.dart';

import 'cli.dart';

/// `ktc hash-pin 1234`: produces a value for "pinHash" in config.json.
final class HashPinCommand extends Command<int> {
  HashPinCommand(this._context) {
    argParser.addOption(
      'iterations',
      help: 'PBKDF2 iterations.',
      defaultsTo: '$defaultPinIterations',
    );
  }

  final CliContext _context;

  @override
  String get name => 'hash-pin';

  @override
  String get description =>
      'Hash a PIN for the "pinHash" field of config.json.';

  @override
  String get invocation => 'ktc hash-pin <pin>';

  @override
  int run() {
    final rest = argResults!.rest;
    if (rest.length != 1 || rest.single.isEmpty) {
      usageException('Pass exactly one PIN.');
    }
    final iterations = int.tryParse(argResults!.option('iterations')!);
    if (iterations == null || iterations < 1) {
      usageException('--iterations must be a positive number.');
    }
    _context.out.writeln(hashPin(rest.single, iterations: iterations));
    return 0;
  }
}
