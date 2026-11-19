import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_constants.dart';
import '../../core/app_logger.dart';
import '../../service/http/http_service.dart';
import '../health/app_health.dart';

part 'server_event.dart';
part 'server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  ServerBloc(this._httpService) : super(const ServerState()) {
    on<ServerStartRequested>(_onStartRequested);
    on<ServerStopped>(_onStopped);
  }

  final HttpService _httpService;
  Timer? _probeTimer;
  int _failedProbes = 0;

  static const _probeInterval = Duration(seconds: 15);

  Future<void> _onStartRequested(
    ServerStartRequested event,
    Emitter<ServerState> emit,
  ) async {
    emit(state.copyWith(status: ServerStatus.starting));
    try {
      await _httpService.start();
      appLogger.info('Server $kHttpPort-portda ishga tushdi');
      emit(state.copyWith(status: ServerStatus.running));
      _startProbing();
    } catch (e) {
      appLogger.severe('Server ishga tushmadi: $e');
      emit(
        state.copyWith(status: ServerStatus.error, errorMessage: e.toString()),
      );
    }
  }

  void _onStopped(ServerStopped event, Emitter<ServerState> emit) {
    _probeTimer?.cancel();
    emit(
      state.copyWith(
        status: ServerStatus.error,
        errorMessage: kServerStoppedMessage,
      ),
    );
  }

  /// Printer serveri keyinchalik to'xtab qolsa sezish uchun portga davriy
  /// ulanib ko'riladi (ketma-ket 2 marta o'xshamasa — xato).
  void _startProbing() {
    _probeTimer?.cancel();
    _failedProbes = 0;
    _probeTimer = Timer.periodic(_probeInterval, (_) async {
      if (await _isPortAlive()) {
        _failedProbes = 0;
        return;
      }
      if (++_failedProbes >= 2) {
        appLogger.severe('Printer serveri $kHttpPort-portda javob bermayapti');
        add(const ServerStopped());
      }
    });
  }

  Future<bool> _isPortAlive() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        kHttpPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _probeTimer?.cancel();
    return super.close();
  }
}
