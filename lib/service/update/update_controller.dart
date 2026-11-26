import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/model/update/update_info.dart';
import 'package:miraprint/service/update/update_checker.dart';

enum UpdateCheckResult { available, upToDate, failed }

/// Update tekshiruvini bitta joyda jamlaydi — AppBar tugmasi va
/// `UpdateAvailableCard` shu bitta natijani (`info`) ko'radi, ikkalasi ham
/// o'z-o'zicha alohida so'rov yubormaydi.
class UpdateController extends ChangeNotifier {
  static const _checkInterval = Duration(hours: 2);

  UpdateInfo? _info;
  UpdateInfo? get info => _info;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  Timer? _timer;

  void startPeriodicChecks() {
    checkNow();
    _timer = Timer.periodic(_checkInterval, (_) => checkNow());
  }

  /// AppBar tugmasi va davriy timer ikkalasi ham shuni chaqiradi. Natija
  /// tugma bosilganda foydalanuvchiga to'g'ri xabar ko'rsatish uchun kerak:
  /// tekshiruv xatosi "yangilanish yo'q" degani emas.
  Future<UpdateCheckResult> checkNow() async {
    if (_isChecking) return _currentResult;

    _isChecking = true;
    notifyListeners();

    try {
      final result = await checkForUpdate();
      appLogger.info(
        result == null
            ? '[UPDATE] Yangilanish yo\'q'
            : '[UPDATE] ${result.version} mavjud (${result.downloadUrl})',
      );
      _info = result;
      return _currentResult;
    } catch (e) {
      // `_info` o'zgarmaydi — avval topilgan yangilanish kartasi yo'qolmaydi.
      appLogger.warning('[UPDATE] Tekshirib bo\'lmadi: $e');
      return UpdateCheckResult.failed;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  UpdateCheckResult get _currentResult => _info == null
      ? UpdateCheckResult.upToDate
      : UpdateCheckResult.available;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
