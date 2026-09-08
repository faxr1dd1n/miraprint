import 'package:flutter/material.dart';

/// Butun ilova bo'ylab bitta xil ko'rinishda ishlatiladigan semantik ranglar.
///
/// Brend/neytral ranglar uchun [Theme.colorScheme] ishlatiladi — bu yerda
/// faqat Material 3 `ColorScheme`da tayyor roli yo'q holatlar (muvaffaqiyat,
/// ogohlantirish) uchun konstantalar beriladi.
abstract final class AppColors {
  static const success = Color(0xFF15803D);
  static const successContainer = Color(0xFFDCFCE7);
  static const warning = Color(0xFFC2410C);
}
