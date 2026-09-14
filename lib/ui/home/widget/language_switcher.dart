import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/service/locale/locale_service.dart';

const _kLanguageNames = {'uz': "O'zbek", 'ru': 'Русский', 'en': 'English'};

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final current = LocalizedApp.of(
      context,
    ).delegate.currentLocale.languageCode;
    final onPrimary =
        Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownMenu<String>(
        initialSelection: current,
        alignmentOffset: const Offset(0, 8),
        leadingIcon: Icon(Icons.language, color: onPrimary),
        trailingIcon: Icon(Icons.arrow_drop_down, color: onPrimary),
        textStyle: TextStyle(fontSize: 16, color: onPrimary),
        requestFocusOnTap: false,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: onPrimary.withValues(alpha: 0.15),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSelected: (code) {
          if (code == null) return;
          changeAppLocale(context, Locale(code));
        },
        dropdownMenuEntries: _kLanguageNames.entries
            .map((e) => DropdownMenuEntry(value: e.key, label: e.value))
            .toList(),
      ),
    );
  }
}
