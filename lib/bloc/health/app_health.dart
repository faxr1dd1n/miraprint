import '../../core/app_constants.dart';
import '../arca_bloc/arca_bloc.dart';
import '../server_bloc/server_bloc.dart';

enum HealthLevel { starting, ok, error }

enum ServiceName { printer, arca }

/// Server ishga tushmaganini yoki keyinroq to'xtab qolganini bildiruvchi
/// (xato matni emas) belgi — UI uni tarjima qiladi.
const String kServerStoppedMessage = 'server_stopped';

class ServiceIssue {
  const ServiceIssue(this.service, this.port, this.rawMessage);

  final ServiceName service;
  final int port;

  /// Asl xato matni yoki [kServerStoppedMessage].
  final String? rawMessage;

  bool get isStopped => rawMessage == kServerStoppedMessage;

  /// Port boshqa dastur/nusxa tomonidan band (macOS, Linux, Windows).
  bool get isPortBusy {
    final m = rawMessage ?? '';
    return m.contains('Address already in use') ||
        m.contains(
          'shared flag to bind()',
        ) || // bir jarayon ichida ikkinchi bind
        m.contains('errno = 48') ||
        m.contains('errno = 98') ||
        m.contains('10048');
  }
}

/// Ilovaning umumiy holati: ikkala lokal server (printer + Arca) ishlasagina
/// "ok". Terminal va printer *qurilmasining* ulanishi bu yerga kirmaydi.
class AppHealth {
  const AppHealth(this.level, this.issues);

  final HealthLevel level;
  final List<ServiceIssue> issues;

  factory AppHealth.from(ServerState printer, ArcaState arca) {
    final issues = [
      if (printer.status == ServerStatus.error)
        ServiceIssue(ServiceName.printer, kHttpPort, printer.errorMessage),
      if (arca.status == ArcaStatus.error)
        ServiceIssue(ServiceName.arca, kArcaPort, arca.errorMessage),
    ];
    if (issues.isNotEmpty) return AppHealth(HealthLevel.error, issues);
    if (printer.status == ServerStatus.running &&
        arca.status == ArcaStatus.running) {
      return const AppHealth(HealthLevel.ok, []);
    }
    return const AppHealth(HealthLevel.starting, []);
  }
}
