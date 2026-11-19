import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_translate/flutter_translate.dart';

import '../../../bloc/arca_bloc/arca_bloc.dart';
import '../../../bloc/health/app_health.dart';
import '../../../bloc/server_bloc/server_bloc.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../service/arca/arca_bridge_server.dart';
import '../../../service/http/http_service.dart';
import 'section_card.dart';

/// Umumiy holat kartasi: yuqorida umumiy natija, pastda har bir lokal server
/// (Arca va printer) o'z qatorida — nomi, vazifasi, manzili, holati va so'rovlari.
class ServerStatusCard extends StatelessWidget {
  const ServerStatusCard({super.key, required this.bridge});

  final ArcaBridgeServer bridge;

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);
    final printer = context.watch<ServerBloc>().state;
    final arca = context.watch<ArcaBloc>().state;
    final health = AppHealth.from(printer, arca);

    final (color, label, hint) = switch (health.level) {
      HealthLevel.starting => (
        AppColors.warning,
        translate('server_status.starting'),
        translate('server_status.hint_starting'),
      ),
      HealthLevel.ok => (
        AppColors.success,
        translate('server_status.running'),
        translate('server_status.hint_ok'),
      ),
      HealthLevel.error => (
        AppColors.danger,
        translate('server_status.error'),
        translate('server_status.hint_error'),
      ),
    };

    ServiceIssue? issueOf(ServiceName n) {
      for (final i in health.issues) {
        if (i.service == n) return i;
      }
      return null;
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulseDot(color: color, pulsing: health.level == HealthLevel.ok),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ServiceRow(
            name: translate('server_status.arca_name'),
            description: translate('server_status.arca_desc'),
            address: kArcaServerUrl,
            status: _levelOf(
              arca.status == ArcaStatus.running,
              arca.status == ArcaStatus.error,
            ),
            issue: issueOf(ServiceName.arca),
            requests: bridge.requestCount,
            lastSeen: bridge.lastSeen,
          ),
          const SizedBox(height: 10),
          _ServiceRow(
            name: translate('server_status.printer_name'),
            description: translate('server_status.printer_desc'),
            address: 'http://127.0.0.1:$kHttpPort',
            status: _levelOf(
              printer.status == ServerStatus.running,
              printer.status == ServerStatus.error,
            ),
            issue: issueOf(ServiceName.printer),
            requests: printerRequestCount,
            lastSeen: printerLastSeen,
          ),
        ],
      ),
    );
  }

  static HealthLevel _levelOf(bool running, bool error) => error
      ? HealthLevel.error
      : (running ? HealthLevel.ok : HealthLevel.starting);
}

/// Bitta lokal server qatori: holat nuqtasi, nomi, vazifasi, manzili (nusxalash
/// bilan) va so'rovlar soni / oxirgi murojaat. Xatoda sabab shu qatorning o'zida.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.description,
    required this.address,
    required this.status,
    required this.issue,
    required this.requests,
    required this.lastSeen,
  });

  final String name;
  final String description;
  final String address;
  final HealthLevel status;
  final ServiceIssue? issue;
  final ValueListenable<int> requests;
  final ValueListenable<DateTime?> lastSeen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = switch (status) {
      HealthLevel.ok => AppColors.success,
      HealthLevel.starting => AppColors.warning,
      HealthLevel.error => AppColors.danger,
    };
    final stateLabel = switch (status) {
      HealthLevel.ok => translate('server_status.running'),
      HealthLevel.starting => translate('server_status.starting'),
      HealthLevel.error => translate('server_status.error'),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: status == HealthLevel.error
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Text(
                      name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      stateLabel,
                      style: text.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (issue != null)
                  Text(
                    _reasonText(issue!),
                    style: text.bodySmall?.copyWith(color: AppColors.danger),
                  )
                else
                  ValueListenableBuilder<int>(
                    valueListenable: requests,
                    builder: (_, n, _) => ValueListenableBuilder<DateTime?>(
                      valueListenable: lastSeen,
                      builder: (_, t, _) => Text(
                        '${translate('arca.requests')}: $n'
                        '  ·  ${translate('arca.last_request')}: '
                        '${t == null ? '—' : _hms(t)}',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: SelectableText(
                        address,
                        style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontFamilyFallback: ['Consolas', 'monospace'],
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    _CopyButton(text: address),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "17865-port band (...)" ko'rinishidagi tushunarli sabab.
String _reasonText(ServiceIssue issue) => issue.isPortBusy
    ? translate('server_status.port_busy', args: {'port': issue.port})
    : issue.isStopped
    ? translate('server_status.stopped')
    : (issue.rawMessage ?? translate('server_status.error'));

String _hms(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Holat nuqtasi; ishlayotganda yumshoq "puls" qiladi.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat();
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.pulsing) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: 18 + 26 * _c.value,
                height: 18 + 26 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.28 * (1 - _c.value)),
                ),
              ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => copied = false);
  }

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);
    return IconButton(
      tooltip: translate('arca.copy'),
      visualDensity: VisualDensity.compact,
      onPressed: _copy,
      icon: Icon(
        copied ? Icons.check_rounded : Icons.copy_rounded,
        size: 18,
        color: copied ? AppColors.success : AppColors.textSecondary,
      ),
    );
  }
}
