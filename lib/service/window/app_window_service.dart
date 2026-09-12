import 'dart:io';

import 'package:miraprint/core/app_logger.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// X tugmasi bilan oynani yopishni ushlab qolib, o'rniga tray'ga yashiradi —
/// shu tarzda HTTP server oyna yopilgandan keyin ham ishlashda davom etadi.
/// Tray menyusi orqaligina ilova haqiqatan to'xtatiladi ("Chiqish").
class AppWindowService with WindowListener, TrayListener {
  Future<void> init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    trayManager.addListener(this);
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png',
    );
    await trayManager.setToolTip('Miraprint');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Ochish'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Chiqish'),
        ],
      ),
    );
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
    appLogger.info('Oyna yashirildi, server fonda ishlashda davom etmoqda');
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'exit':
        appLogger.info('Foydalanuvchi tray orqali ilovani to\'liq to\'xtatdi');
        exit(0);
    }
  }
}
