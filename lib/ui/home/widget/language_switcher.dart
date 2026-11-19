import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/core/app_colors.dart';
import 'package:miraprint/service/locale/locale_service.dart';

const _kLanguageNames = {'uz': "O'zbek", 'ru': 'Русский', 'en': 'English'};

/// Sarlavhadagi ixcham til tanlagich (UZ / RU / EN).
///
/// `PopupMenuButton` o'rniga o'z `InkWell`i ishlatilgan: standart popup tugma
/// dumaloq "pill" ortida to'rtburchak splash/hover chizardi. Menyu tugma
/// *ostida* ochiladi (tugmani yopib qo'ymaydi).
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  Future<void> _openMenu(BuildContext context, String current) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = button.localToGlobal(
      Offset(0, button.size.height + 8),
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - topLeft.dx - button.size.width,
      overlay.size.height - topLeft.dy,
    );

    final code = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      items: [
        for (final e in _kLanguageNames.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: e.key == current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.accent,
                        )
                      : null,
                ),
                Text(e.value),
              ],
            ),
          ),
      ],
    );
    if (code != null && context.mounted) {
      changeAppLocale(context, Locale(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);
    final current = LocalizedApp.of(
      context,
    ).delegate.currentLocale.languageCode;

    return Tooltip(
      message: translate('language.label'),
      // Builder: menyu o'rni aynan tugmaning o'z konteksti bo'yicha hisoblanadi.
      child: Builder(
        builder: (buttonContext) => InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openMenu(buttonContext, current),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  current.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
