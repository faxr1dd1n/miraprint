import 'dart:io';

import 'package:flutter/material.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/model/update/update_info.dart';
import 'package:miraprint/service/update/update_checker.dart';
import 'package:miraprint/service/update/update_downloader.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';

class UpdateAvailableCard extends StatefulWidget {
  const UpdateAvailableCard({super.key});

  @override
  State<UpdateAvailableCard> createState() => _UpdateAvailableCardState();
}

class _UpdateAvailableCardState extends State<UpdateAvailableCard> {
  UpdateInfo? _updateInfo;
  bool _isDownloading = false;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  UpdateCancelToken? _cancelToken;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await checkForUpdate();
      appLogger.info(
        info == null
            ? 'Update tekshiruvi: yangilanish yo\'q (kAppVersion joriy/yangi)'
            : 'Update tekshiruvi: ${info.version} mavjud (${info.downloadUrl})',
      );
      if (mounted) setState(() => _updateInfo = info);
    } catch (e) {
      // Server ishlamasa (masalan test bosqichida) ham UI'da xato
      // ko'rsatilmaydi — faqat logga yoziladi, diagnostika uchun.
      appLogger.warning('Update tekshiruvida xato: $e');
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _updateInfo;
    if (info == null) return;

    final cancelToken = UpdateCancelToken();
    setState(() {
      _isDownloading = true;
      _receivedBytes = 0;
      _totalBytes = 0;
      _cancelToken = cancelToken;
      _errorMessage = null;
    });
    try {
      final filePath = await downloadInstaller(
        info.downloadUrl,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );
      // Ilova ishlab turgan holda eski faylni almashtirib bo'lmaydi
      // ("band fayl" xatosi) — shu sabab avval (ilova hali oldinda, dialog
      // ko'rinadigan holatda) foydalanuvchini ogohlantiramiz, keyingina
      // Finder'ni ochamiz (bu oynani orqaga suradi) va ilova yopiladi.
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Yuklab olindi'),
            content: const Text(
              'Davom etish uchun quyidagi tugmani bosing. Finder ochiladi — '
              'Miraprint\'ni Applications papkasiga torting, so\'ng uni '
              'qayta oching. Bu ilova hozir yopiladi.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Davom etish'),
              ),
            ],
          ),
        );
      }
      await launchInstaller(filePath);
      exit(0);
    } on UpdateCancelledException {
      // Foydalanuvchi o'zi bekor qilgan — xato sifatida ko'rsatilmaydi.
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _cancelToken = null;
        });
      }
    }
  }

  void _cancelDownload() => _cancelToken?.cancel();

  String _formatBytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final info = _updateInfo;
    if (info == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final progress = _totalBytes > 0 ? _receivedBytes / _totalBytes : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SectionCard(
        title: 'Yangilanish mavjud',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Yangi versiya: ${info.version}')),
                if (_isDownloading)
                  TextButton(
                    onPressed: _cancelDownload,
                    child: const Text('Bekor qilish'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadAndInstall,
                  icon: _isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Yuklanmoqda...' : 'Yangilash'),
                ),
              ],
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress),
              ),
              const SizedBox(height: 4),
              Text(
                _totalBytes > 0
                    ? '${_formatBytes(_receivedBytes)} MB / ${_formatBytes(_totalBytes)} MB'
                    : '${_formatBytes(_receivedBytes)} MB yuklandi',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
