import 'dart:io';

import 'package:miraprint/service/printer/mac_raw_printer_connection.dart';
import 'package:miraprint/service/printer/windows_raw_printer_connection.dart';

abstract class PrinterConnection {
  factory PrinterConnection.forPlatform(String printerName) {
    if (Platform.isMacOS) {
      return MacRawPrinterConnection(printerName);
    } else if (Platform.isWindows) {
      return WindowsRawPrinterConnection(printerName);
    }
    throw UnsupportedError(
      'Bu platforma qo\'llab quvvatlanmaydi: ${Platform.operatingSystem}',
    );
  }
  Future<void> sendRaw(List<int> bytes);
}
