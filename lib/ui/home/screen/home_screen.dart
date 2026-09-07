import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/model/receipt/header_item.dart';
import 'package:miraprint/model/receipt/receipt_data.dart';
import 'package:miraprint/model/receipt/receipt_item.dart';
import 'package:miraprint/model/receipt/total_item.dart';
import 'package:miraprint/service/printer/mac_printer_lister.dart';
import 'package:miraprint/service/printer/printer_connection.dart';
import 'package:miraprint/service/receipt/last_receipt_notifier.dart';
import 'package:miraprint/service/receipt/receipt_builder.dart';
import 'package:miraprint/ui/home/widget/receipt_preview.dart';
import 'package:miraprint/ui/home/widget/server_status_widget.dart';
import 'package:printing/printing.dart';

import 'package:miraprint/model/update/update_info.dart';
import 'package:miraprint/service/update/update_checker.dart';
import 'package:miraprint/service/update/update_downloader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UpdateInfo? _updateInfo;
  bool _isDownloadingUpdate = false;
  List<Printer> _printers = [];
  Printer? _selectedPrinter;
  bool _isLoadingPrinters = false;
  bool _isTestPrinting = false;
  ({bool success, String message})? _testPrintResult;
  void _showReceiptPreview() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ReceiptPreview(receipt: _sampleReceipt()),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<ServerBloc>().add(const ServerStartRequested());
    _loadPrinters();
    _checkForUpdate();
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
      final bytes = await buildReceiptBytes(_sampleReceipt());
      await PrinterConnection.forPlatform(printer.name).sendRaw(bytes);
      setState(
        () => _testPrintResult = (
          success: true,
          message: '${printer.name} printerga yuborildi',
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

  Future<void> _checkForUpdate() async {
    try {
      final info = await checkForUpdate();
      if (mounted) setState(() => _updateInfo = info);
    } catch (_) {
      // test bosqichida server ishlamasa, jim o'tkazamiz
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    final info = _updateInfo;
    if (info == null) return;

    setState(() => _isDownloadingUpdate = true);
    try {
      final filePath = await downloadInstaller(info.downloadUrl);
      await launchInstaller(filePath);
    } catch (e) {
      setState(
        () => _testPrintResult = (success: false, message: e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingUpdate = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miraprint'),
        backgroundColor: Colors.amber,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_updateInfo != null) ...[
                  _SectionCard(
                    title: 'Yangilanish mavjud',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Yangi versiya: ${_updateInfo!.version}'),
                        ),
                        FilledButton.icon(
                          onPressed: _isDownloadingUpdate
                              ? null
                              : _downloadAndInstallUpdate,
                          icon: _isDownloadingUpdate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _isDownloadingUpdate
                                ? 'Yuklanmoqda...'
                                : 'Yangilash',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionCard(
                  title: 'Server holati',
                  child: const ServerStatusWidget(),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Printer',
                  trailing: IconButton.filledTonal(
                    onPressed: _isLoadingPrinters ? null : _loadPrinters,
                    icon: const Icon(Icons.refresh),
                    iconSize: 22,
                    tooltip: 'Yangilash',
                  ),
                  child: _buildPrinterSection(),
                ),
                if (_testPrintResult != null) ...[
                  const SizedBox(height: 20),
                  _ResultBanner(result: _testPrintResult!),
                ],
                const SizedBox(height: 20),
                _SectionCard(
                  title: "So'nggi qabul qilingan chek (POST /print)",
                  child: ValueListenableBuilder<ReceiptData?>(
                    valueListenable: lastReceiptNotifier,
                    builder: (context, receipt, _) {
                      if (receipt == null) {
                        return const Text(
                          "Hali hech qanday chek qabul qilinmagan",
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        );
                      }
                      return Center(child: ReceiptPreview(receipt: receipt));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoadingPrinters)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_printers.isEmpty)
          const Text(
            'Printer topilmadi',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          )
        else ...[
          DropdownButtonFormField<Printer>(
            initialValue: _selectedPrinter,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
            items: _printers
                .map(
                  (printer) => DropdownMenuItem(
                    value: printer,
                    child: Text(
                      printer.name,
                      style: const TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (printer) => setState(() => _selectedPrinter = printer),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectedPrinter == null || _isTestPrinting
                ? null
                : _testPrint,
            icon: _isTestPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            label: Text(
              _isTestPrinting ? 'Yuborilmoqda...' : 'Test Print',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showReceiptPreview,
          icon: const Icon(Icons.receipt_long),
          label: const Text('Chekni ko\'rish', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final ({bool success, String message}) result;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = result.success
        ? (Colors.green.shade50, Colors.green.shade200, Colors.green.shade700)
        : (Colors.red.shade50, Colors.red.shade200, Colors.red.shade700);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: fg,
            size: 55,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(color: fg, fontSize: 22),
            ),
          ),
        ],
      ),
    );
  }
}
