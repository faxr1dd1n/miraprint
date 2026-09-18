import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_version.dart';
import 'package:miraprint/service/update/update_controller.dart';
import 'package:miraprint/ui/home/widget/language_switcher.dart';
import 'package:miraprint/ui/home/widget/last_receipt_section.dart';
import 'package:miraprint/ui/home/widget/printer_section.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';
import 'package:miraprint/ui/home/widget/server_status_widget.dart';
import 'package:miraprint/ui/home/widget/update_available_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final updateController = UpdateController();

  @override
  void initState() {
    super.initState();
    context.read<ServerBloc>().add(const ServerStartRequested());
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
      appBar: AppBar(
        title: Text(translate('app.title', args: {'version': kAppVersion})),
        actions: const [LanguageSwitcher()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UpdateAvailableCard(controller: updateController),
                SectionCard(
                  title: translate('server_status.title'),
                  trailing: ListenableBuilder(
                    listenable: updateController,
                    builder: (context, _) {
                      if (updateController.isChecking) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return InkWell(
                        onTap: onCheckUpdatePressed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.update,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                translate('update.check_button'),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  child: const ServerStatusWidget(),
                ),
                const SizedBox(height: 20),
                const PrinterSection(),
                const SizedBox(height: 20),
                const LastReceiptSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
