import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'agent_app.dart';
import 'agent_controller.dart';
import 'strings.dart';

/// The window and the tray icon: hidden until the service has something to
/// say, then on top of everything (games included).
final class DesktopShell with WindowListener, TrayListener {
  DesktopShell(this.controller, this.strings);

  final AgentController controller;
  final Strings strings;
  var _visible = false;
  String? _lastTray;

  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: const Size(440, 400),
        center: true,
        title: strings.title,
        skipTaskbar: false,
        alwaysOnTop: true,
        titleBarStyle: TitleBarStyle.normal,
      ),
    );
    await windowManager.setResizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon('assets/tray.ico');
    trayManager.addListener(this);

    controller.addListener(_update);
    await _update();
  }

  Future<void> _update() async {
    final wanted = controller.prompt != null || controller.notice != null;
    if (wanted && !_visible) {
      _visible = true;
      await windowManager.center();
      // A question takes the focus; a notification must not steal it from the game.
      await windowManager.show(inactive: controller.prompt == null);
      await windowManager.setAlwaysOnTop(true);
      if (controller.prompt != null) await windowManager.focus();
    } else if (wanted && controller.prompt != null) {
      await windowManager.focus();
    } else if (!wanted && _visible) {
      _visible = false;
      await windowManager.hide();
    }
    await _updateTray();
  }

  Future<void> _updateTray() async {
    final text = statusText(controller, strings);
    final loggedIn = controller.status.childName != null;
    final key = '$text|$loggedIn';
    if (key == _lastTray) return;
    _lastTray = key;
    await trayManager.setToolTip('${strings.title}\n$text');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: text, disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'logout', label: strings.logout, disabled: !loggedIn),
        ],
      ),
    );
  }

  // Closing the window (Alt+F4, the cross) answers "Cancel".
  @override
  void onWindowClose() {
    if (controller.prompt != null) {
      controller.cancel();
    } else {
      controller.dismissNotice();
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'logout') controller.logout();
  }
}
