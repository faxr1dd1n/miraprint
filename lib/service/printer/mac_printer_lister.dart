import 'dart:io';

import 'package:printing/printing.dart';

Future<List<Printer>> listMacPrinters() async {
  final namesResult = await Process.run('lpstat', ['-e']);
  final names = (namesResult.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final defaultResult = await Process.run('lpstat', ['-d']);
  final defaultOutput = (defaultResult.stdout as String).trim();
  final defaultName = defaultOutput.contains(':')
      ? defaultOutput.split(':').last.trim()
      : '';

  return names
      .map(
        (name) =>
            Printer(url: name, name: name, isDefault: name == defaultName),
      )
      .toList();
}
