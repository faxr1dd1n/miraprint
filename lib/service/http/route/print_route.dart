import 'dart:convert';

import 'package:miraprint/model/printer/print_request.dart';
import 'package:miraprint/model/printer/print_response.dart';
import 'package:miraprint/service/printer/printer_connection.dart';
import 'package:miraprint/service/receipt/last_receipt_notifier.dart';
import 'package:miraprint/service/receipt/receipt_builder.dart';
import 'package:shelf/shelf.dart';

Future<Response> handlePostPrint(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final printRequest = PrintRequest.fromJson(json);
    lastReceiptNotifier.value = printRequest.check;

    final bytes = await buildReceiptBytes(
      printRequest.check,
      settings: printRequest.receiptSettings,
    );
    final connection = PrinterConnection.forPlatform(printRequest.printer.name);
    await connection.sendRaw(bytes);
    final response = PrintResponse(success: true, message: "Chek chop etildi");
    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    final response = PrintResponse(success: false, message: e.toString());
    return Response(
      400,
      body: jsonEncode(response.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }
}
