import '../../model/arca/terminal_target.dart';
import 'wss_arca_client.dart';

class TerminalUnreachableException implements Exception {
  TerminalUnreachableException(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

class TerminalTimeoutException implements Exception {
  @override
  String toString() => 'Terminal javob bermadi (timeout)';
}

/// ARCA terminali bilan aloqa.
abstract class ArcaClient {
  /// Terminalga ulanish mumkinmi (hech qanday buyruq yuborilmaydi).
  Future<bool> check(TerminalTarget target);

  /// [request]ni (faqat `id`/`command`/`data`) terminalga yuboradi va terminal
  /// javobini matn ko'rinishida, o'zgartirmasdan qaytaradi.
  Future<String> execute(
    TerminalTarget target,
    Map<String, dynamic> request,
    Duration timeout,
  );

  factory ArcaClient.wss() => WssArcaClient();
}
