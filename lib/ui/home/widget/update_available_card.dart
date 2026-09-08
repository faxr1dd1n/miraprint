import 'package:flutter/material.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await checkForUpdate();
      if (mounted) setState(() => _updateInfo = info);
    } catch (_) {
      // test bosqichida server ishlamasa, jim o'tkazamiz
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _updateInfo;
    if (info == null) return;

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });
    try {
      final filePath = await downloadInstaller(info.downloadUrl);
      await launchInstaller(filePath);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _updateInfo;
    if (info == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

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
                FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadAndInstall,
                  icon: _isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Yuklanmoqda...' : 'Yangilash'),
                ),
              ],
            ),
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
