import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/agent_app.dart';
import 'src/agent_controller.dart';
import 'src/desktop.dart';
import 'src/strings.dart';
import 'src/windows.dart';

const _version = '0.1.0';

/// Kids Time Control tray agent: started at logon for every Windows user
/// (installed by `packaging/windows/install.ps1`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!claimSingleInstance()) exit(0);

  final strings = Strings.forLocale(Platform.localeName);
  final controller = AgentController(
    connect: connectToService,
    sessionId: currentSessionId(),
    userIsAdmin: currentUserIsAdmin(),
    version: _version,
  )..start();

  runApp(AgentApp(controller: controller, strings: strings));
  await DesktopShell(controller, strings).init();
}
