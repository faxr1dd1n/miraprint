import 'package:flutter/widgets.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> kSupportedLocales = ['uz', 'ru', 'en'];
const String kFallbackLocale = 'uz';

/// `MaterialApp`ning o'z `locale`/`localizationsDelegates` xususiyatlarini
/// qayta o'qitish uchun (`main.dart`da `ValueListenableBuilder` bilan) —
/// `MaterialApp` ildizda (`Navigator`dan tashqarida) joylashgani uchun bu
/// xavfsiz ishlaydi. Lekin `Navigator` allaqachon ko'rsatgan ekran (`home:`
/// ichidagi hammasi) uchun bu YETARLI EMAS — Flutter'ning tanilgan
/// cheklovi bo'yicha `MaterialApp.home` o'zgarishi allaqachon push qilingan
/// marshrutni qayta qurmaydi. Shu sababli chuqurroqdagi widgetlar uchun
/// pastdagi `changeAppLocale` qo'shimcha ravishda `LocalizedAppState`ning
/// o'z `LocalizationProvider` (InheritedWidget) mexanizmini ham ishga
/// tushiradi — har bir tarjima ko'rsatuvchi widget `build()`ida
/// `LocalizationProvider.of(context)` chaqirishi shart (`onebuy-flutter-mobile`
/// bilan bir xil qoida).
final ValueNotifier<int> localeTick = ValueNotifier<int>(0);

class _SharedPrefsTranslatePreferences implements ITranslatePreferences {
  static const _key = 'app_language';

  @override
  Future<void> savePreferredLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  @override
  Future<Locale?> getPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    return code == null ? null : Locale(code);
  }
}

Future<LocalizationDelegate> createLocalizationDelegate() {
  return LocalizationDelegate.create(
    fallbackLocale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    preferences: _SharedPrefsTranslatePreferences(),
  );
}

Future<void> changeAppLocale(BuildContext context, Locale locale) async {
  final delegate = LocalizedApp.of(context).delegate;
  await delegate.changeLocale(locale);
  if (!context.mounted) return;
  context.findAncestorStateOfType<LocalizedAppState>()?.onLocaleChanged();
  localeTick.value++;
}
