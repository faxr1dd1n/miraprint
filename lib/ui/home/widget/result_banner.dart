import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

class ResultBanner extends StatelessWidget {
  const ResultBanner({super.key, required this.result});

  final ({bool success, String message}) result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bg, border, fg) = result.success
        ? (
            AppColors.successContainer,
            AppColors.success.withValues(alpha: 0.4),
            AppColors.success,
          )
        : (
            colorScheme.errorContainer,
            colorScheme.error.withValues(alpha: 0.4),
            colorScheme.onErrorContainer,
          );

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
