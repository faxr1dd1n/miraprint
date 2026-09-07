import 'dart:convert';
import 'dart:io';

import 'package:miraprint/model/printer/printer_info.dart';
import 'package:miraprint/service/printer/mac_printer_lister.dart';
import 'package:printing/printing.dart';
import 'package:shelf/shelf.dart';

Future<Response> handleGetPrinters(Request request) async {
  final printers = Platform.isMacOS
      ? await listMacPrinters()
      : await Printing.listPrinters();

  final result = printers
      .map(
        (printer) => PrinterInfo(
          name: printer.name,
          isDefault: printer.isDefault,
        ).toJson(),
      )
      .toList();

  return Response.ok(
    jsonEncode(result),
    headers: {'content-type': 'application/json'},
  );
}
