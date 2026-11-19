import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/bloc/arca_bloc/arca_bloc.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_colors.dart';
import 'package:miraprint/core/app_version.dart';
import 'package:miraprint/service/arca/arca_bridge_server.dart';
import 'package:miraprint/service/update/update_controller.dart';
import 'package:miraprint/ui/home/widget/server_status_card.dart';
import 'package:miraprint/ui/home/widget/language_switcher.dart';
import 'package:miraprint/ui/home/widget/printer_section.dart';
import 'package:miraprint/ui/home/widget/update_available_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.arcaServer});

  final ArcaBridgeServer arcaServer;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final updateController = UpdateController();

  @override
  void initState() {
    super.initState();
    context.read<ServerBloc>().add(const ServerStartRequested());
    context.read<ArcaBloc>().add(const ArcaStartRequested());
    updateController.startPeriodicChecks();
  }

  @override
  void dispose() {
    updateController.dispose();
    super.dispose();
  }

  Future<void> onCheckUpdatePressed() async {
    final found = await updateController.checkNow();
    if (!found && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('update.no_update_found'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Til o'zgarishini `Navigator` marshrutidan mustaqil, to'g'ridan-to'g'ri
    // ushlab olish uchun (`locale_service.dart`dagi izohga qarang).
    LocalizationProvider.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  updateController: updateController,
                  onCheckUpdate: onCheckUpdatePressed,
                ),
                const SizedBox(height: 28),
                UpdateAvailableCard(controller: updateController),
                ServerStatusCard(bridge: widget.arcaServer),
                const SizedBox(height: 16),
                const PrinterSection(),
                const SizedBox(height: 20),
                Text(
                  translate('footer.tray_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.updateController, required this.onCheckUpdate});

  final UpdateController updateController;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/miraprint_logo.png',
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Miraprint',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                translate('app.subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _UpdateButton(controller: updateController, onPressed: onCheckUpdate),
        const SizedBox(width: 8),
        const LanguageSwitcher(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'v$kAppVersion',
            style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// "Yangilanishni tekshirish" tugmasi: ikonka + yorliq; tekshirilayotganda spinner.
class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.controller, required this.onPressed});

  final UpdateController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final checking = controller.isChecking;
        return Tooltip(
          message: translate('update.check_button'),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: checking ? null : onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                  const SizedBox(width: 6),
                  Text(
                    translate('update.check_short'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
