/// So'rov ichidagi `terminal: {ip, port}`.
class TerminalTarget {
  const TerminalTarget(this.ip, this.port);

  final String ip;
  final int port;

  static TerminalTarget? tryParse(Object? json) {
    if (json is! Map) return null;
    final ip = json['ip'];
    final port = json['port'] is int
        ? json['port'] as int
        : int.tryParse('${json['port']}');
    if (ip is! String || ip.trim().isEmpty || port == null) return null;
    return TerminalTarget(ip.trim(), port);
  }

  @override
  String toString() => '$ip:$port';
}
