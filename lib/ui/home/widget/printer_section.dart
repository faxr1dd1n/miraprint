import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/model/receipt/header_item.dart';
import 'package:miraprint/model/receipt/receipt_data.dart';
import 'package:miraprint/model/receipt/receipt_item.dart';
import 'package:miraprint/model/receipt/total_item.dart';
import 'package:miraprint/service/printer/mac_printer_lister.dart';
import 'package:miraprint/service/printer/printer_connection.dart';
import 'package:miraprint/service/receipt/receipt_builder.dart';
import 'package:miraprint/service/receipt/receipt_canvas_renderer.dart';
import 'package:miraprint/ui/home/widget/result_banner.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';
import 'package:printing/printing.dart';

class PrinterSection extends StatefulWidget {
  const PrinterSection({super.key});

  @override
  State<PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends State<PrinterSection> {
  List<Printer> _printers = [];
  Printer? _selectedPrinter;
  bool _isLoadingPrinters = false;
  bool _isTestPrinting = false;
  ({bool success, String message})? _testPrintResult;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final printers = Platform.isMacOS
        ? await listMacPrinters()
        : await Printing.listPrinters();
    setState(() {
      _printers = printers;
      _selectedPrinter = printers.isNotEmpty ? printers.first : null;
      _isLoadingPrinters = false;
    });
  }

  Future<void> _testPrint() async {
    final printer = _selectedPrinter;
    if (printer == null) return;

    setState(() {
      _isTestPrinting = true;
      _testPrintResult = null;
    });

    try {
      final bytes = await buildReceiptBytes(
        _sampleReceipt(),
        extraImageBuilder: renderSocialIconsTestImage,
      );
      await PrinterConnection.forPlatform(printer.name).sendRaw(bytes);
      setState(
        () => _testPrintResult = (
          success: true,
          message: translate('printer.sent_success', args: {'name': printer.name}),
        ),
      );
    } catch (e) {
      setState(
        () => _testPrintResult = (success: false, message: e.toString()),
      );
    } finally {
      setState(() => _isTestPrinting = false);
    }
  }

  ReceiptData _sampleReceipt() {
    return const ReceiptData(
      logo: 'https://mirasoft.io/assets/i/logo.jpg',
      currentNumber: '1',
      headers: [HeaderItem(title: 'Компания', val: 'Miraprint')],
      items: [
        ReceiptItem(
          name: 'Sinov mahsuloti',
          qty: 1,
          price: '10 000',
          totalPrice: '10 000',
        ),
      ],
      totals: [TotalItem(title: 'Jami', val: '10 000', big: true)],
      barcode: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: translate('printer.title'),
      trailing: IconButton.filledTonal(
        onPressed: _isLoadingPrinters ? null : _loadPrinters,
        icon: const Icon(Icons.refresh),
        iconSize: 22,
        tooltip: translate('common.refresh'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoadingPrinters)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_printers.isEmpty)
            Text(
              translate('printer.not_found'),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            )
          else ...[
            DropdownMenu<Printer>(
              key: ValueKey(_printers),
              initialSelection: _selectedPrinter,
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: false,
              textStyle: const TextStyle(fontSize: 18),
              dropdownMenuEntries: _printers
                  .map(
                    (printer) => DropdownMenuEntry(
                      value: printer,
                      label: printer.name,
                      style: MenuItemButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (printer) =>
                  setState(() => _selectedPrinter = printer),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectedPrinter == null || _isTestPrinting
                  ? null
                  : _testPrint,
              icon: _isTestPrinting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.print),
              label: Text(
                _isTestPrinting
                    ? translate('common.sending')
                    : translate('printer.test_print'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
          if (_testPrintResult != null) ...[
            const SizedBox(height: 20),
            ResultBanner(result: _testPrintResult!),
          ],
        ],
      ),
    );
  }
}
