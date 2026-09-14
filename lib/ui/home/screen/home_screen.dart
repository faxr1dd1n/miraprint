import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_version.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<ServerBloc>().add(const ServerStartRequested());
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
                const UpdateAvailableCard(),
                SectionCard(
                  title: translate('server_status.title'),
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
