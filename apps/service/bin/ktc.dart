import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ktc_service/ktc_service.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await buildCli(CliContext.system()).run(arguments) ?? 0;
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
  // stdin/signal subscriptions may keep the VM alive.
  exit(exitCode);
}
