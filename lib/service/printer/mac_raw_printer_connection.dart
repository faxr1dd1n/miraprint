import 'dart:convert';
import 'dart:io';

import 'package:miraprint/service/printer/printer_connection.dart';

class MacRawPrinterConnection implements PrinterConnection {
  const MacRawPrinterConnection(this.printerName);
  final String printerName;

  @override
  Future<void> sendRaw(List<int> bytes) async {
    final process = await Process.start('lp', ['-d', printerName, '-o', 'raw']);
    process.stdin.add(bytes);
    await process.stdin.close();

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final error = await process.stderr.transform(utf8.decoder).join();
      throw Exception('Printerga yuborib bo\'lmadi ($printerName): $error');
    }
  }
}
