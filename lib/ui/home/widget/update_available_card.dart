import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/service/update/update_controller.dart';
import 'package:miraprint/service/update/update_downloader.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';

class UpdateAvailableCard extends StatefulWidget {
  const UpdateAvailableCard({required this.controller, super.key});

  final UpdateController controller;

  @override
  State<UpdateAvailableCard> createState() => _UpdateAvailableCardState();
}

class _UpdateAvailableCardState extends State<UpdateAvailableCard> {
  bool _isDownloading = false;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  UpdateCancelToken? _cancelToken;
  String? _errorMessage;

  Future<void> _downloadAndInstall() async {
    final info = widget.controller.info;
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
            title: Text(translate('update.downloaded_title')),
            content: Text(translate('update.downloaded_body')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(translate('common.continue')),
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
    LocalizationProvider.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final info = widget.controller.info;
        if (info == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final progress = _totalBytes > 0 ? _receivedBytes / _totalBytes : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SectionCard(
            title: translate('update.title'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        translate(
                          'update.new_version',
                          args: {'version': info.version},
                        ),
                      ),
                    ),
                    if (_isDownloading)
                      TextButton(
                        onPressed: _cancelDownload,
                        child: Text(translate('common.cancel')),
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
                      label: Text(
                        _isDownloading
                            ? translate('common.downloading')
                            : translate('update.update_button'),
                      ),
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
                        ? translate(
                            'update.progress_of',
                            args: {
                              'received': _formatBytes(_receivedBytes),
                              'total': _formatBytes(_totalBytes),
                            },
                          )
                        : translate(
                            'update.progress_downloaded',
                            args: {'received': _formatBytes(_receivedBytes)},
                          ),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
