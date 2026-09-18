import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/model/update/update_info.dart';
import 'package:miraprint/service/update/update_checker.dart';

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

  /// AppBar tugmasi va davriy timer ikkalasi ham shuni chaqiradi.
  /// Qaytadi: yangilanish topildimi (tugma bosilganda foydalanuvchiga
  /// "yangilanish yo'q" xabarini ko'rsatish uchun kerak).
  Future<bool> checkNow() async {
    if (_isChecking) return _info != null;

    _isChecking = true;
    notifyListeners();

    try {
      final result = await checkForUpdate();
      appLogger.info(
        result == null
            ? 'Update tekshiruvi: yangilanish yo\'q'
            : 'Update tekshiruvi: ${result.version} mavjud (${result.downloadUrl})',
      );
      _info = result;
      return result != null;
    } catch (e) {
      appLogger.warning('Update tekshiruvida xato: $e');
      return _info != null;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
