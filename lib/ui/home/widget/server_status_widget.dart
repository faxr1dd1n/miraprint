import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/server_bloc/server_bloc.dart';

class ServerStatusWidget extends StatelessWidget {
  const ServerStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final (color, icon, label) = switch (state.status) {
          ServerStatus.initial => (
            Colors.grey,
            Icons.circle_outlined,
            'Kutilmoqda',
          ),
          ServerStatus.starting => (
            Colors.orange,
            Icons.sync,
            'Ishga tushmoqda...',
          ),
          ServerStatus.running => (
            Colors.green,
            Icons.check_circle,
            'Ishlayapti',
          ),
          ServerStatus.error => (Colors.red, Icons.error, 'Xato'),
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
                  style: const TextStyle(color: Colors.red, fontSize: 14),
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
