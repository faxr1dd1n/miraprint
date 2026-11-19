import 'package:flutter/material.dart';

/// Dark dizayn palitrasi. Hamma ranglar shu yerda — ekranlarda to'g'ridan-to'g'ri
/// `Color(0x...)` yozilmaydi.
abstract final class AppColors {
  // Fon qatlamlari (qoradan ochiqqa)
  static const background = Color(0xFF0D0F14);
  static const surface = Color(0xFF151922);
  static const surfaceHigh = Color(0xFF1C212C);
  static const border = Color(0xFF262C3A);

  // Matn
  static const textPrimary = Color(0xFFE8EBF2);
  static const textSecondary = Color(0xFF8B93A7);

  // Aksent va holat ranglari
  static const accent = Color(0xFF5B8CFF);
  static const success = Color(0xFF3DD68C);
  static const successContainer = Color(0xFF12281F);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFFF6B6B);
}
