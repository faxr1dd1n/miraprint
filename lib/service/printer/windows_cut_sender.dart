import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'windows_raw_printer_connection.dart';

/// C# ilovadagi kabi (`MainForm.cs:513-531`): OS drayveri orqali
/// (`Printing.directPrintPdf`) asosiy kontent chop etilgandan KEYIN, qog'oz
/// kesish uchun alohida, kichik XOM ESC/POS bayt yuboriladi — drayver
/// GDI+ orqali kesish komandasini yubora olmaydi, printerning o'z
/// auto-cut sozlamasiga tayanib bo'lmaydi (`PLAN.md`, Bosqich 12). Bu payt
/// printer allaqachon katta print job orqali "isigan" bo'ladi, shuning
/// uchun bu kichik xom yozuv xavfsiz.
Future<void> sendWindowsCutCommand(String printerName) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  // `cut()` ichida qattiq yozilgan `emptyLines(5)` GDI job'dan qolgan qanday
  // qator balandligi holatida bo'lsa o'shanda hisoblanadi (bu job hech qachon
  // reset qilinmagan edi) — oldingi `reset()` uni default holatga qaytarib,
  // ortiqcha bo'shliqni oldini oladi; keyingi `reset()` esa printerni
  // KEYINGI chek uchun toza holatda qoldiradi.
  final bytes = <int>[
    ...generator.reset(),
    ...generator.cut(),
    ...generator.reset(),
  ];
  await WindowsRawPrinterConnection(printerName).sendRaw(bytes);
}
