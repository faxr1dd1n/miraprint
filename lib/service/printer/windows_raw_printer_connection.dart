import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'printer_connection.dart';

class WindowsRawPrinterConnection implements PrinterConnection {
  const WindowsRawPrinterConnection(this.printerName);

  final String printerName;

  @override
  Future<void> sendRaw(List<int> bytes) async {
    final phPrinter = calloc<Pointer>();
    final printerNamePtr = printerName.toNativeUtf16();
    final docNamePtr = 'Miraprint chek'.toNativeUtf16();
    final dataTypePtr = 'RAW'.toNativeUtf16();
    final docInfo = calloc<DOC_INFO_1>();
    final buffer = calloc<Uint8>(bytes.length);
    final pcWritten = calloc<Uint32>();

    try {
      final openResult = OpenPrinter(
        PCWSTR(printerNamePtr),
        phPrinter,
        nullptr,
      );
      if (!openResult.value) {
        throw Exception(
          'Printer ochilmadi ($printerName), Windows xato kodi: ${openResult.error}',
        );
      }
      final hPrinter = PRINTER_HANDLE(phPrinter.value);

      docInfo.ref
        ..pDocName = PWSTR(docNamePtr)
        ..pOutputFile = PWSTR(nullptr)
        ..pDatatype = PWSTR(dataTypePtr);

      final jobId = StartDocPrinter(hPrinter, 1, docInfo);
      if (jobId == 0) {
        throw Exception('Chek job boshlanmadi ($printerName)');
      }

      if (!StartPagePrinter(hPrinter)) {
        throw Exception('Sahifa boshlanmadi ($printerName)');
      }

      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final written = WritePrinter(
        hPrinter,
        buffer.cast(),
        bytes.length,
        pcWritten,
      );
      if (!written || pcWritten.value != bytes.length) {
        throw Exception('Baytlar to\'liq yozilmadi ($printerName)');
      }

      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
      ClosePrinter(hPrinter);
    } finally {
      calloc.free(phPrinter);
      calloc.free(printerNamePtr);
      calloc.free(docNamePtr);
      calloc.free(dataTypePtr);
      calloc.free(docInfo);
      calloc.free(buffer);
      calloc.free(pcWritten);
    }
  }
}
