import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../bloc/server_bloc/server_bloc.dart';
import '../../../core/app_colors.dart';

class ServerStatusWidget extends StatelessWidget {
  const ServerStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // `locale_service.dart`dagi izohga qarang — til o'zgarganda shu widget
    // `Navigator`dan mustaqil ravishda qayta qurilishi uchun kerak.
    LocalizationProvider.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final (color, icon, label) = switch (state.status) {
          ServerStatus.initial => (
            colorScheme.onSurfaceVariant,
            Icons.circle_outlined,
            translate('server_status.waiting'),
          ),
          ServerStatus.starting => (
            AppColors.warning,
            Icons.sync,
            translate('server_status.starting'),
          ),
          ServerStatus.running => (
            AppColors.success,
            Icons.check_circle,
            translate('server_status.running'),
          ),
          ServerStatus.error => (
            colorScheme.error,
            Icons.error,
            translate('server_status.error'),
          ),
        };

        return Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (state.status == ServerStatus.error &&
                state.errorMessage != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: colorScheme.error, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
