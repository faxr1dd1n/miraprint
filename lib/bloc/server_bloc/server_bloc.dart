import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_constants.dart';
import '../../core/app_logger.dart';
import '../../service/http/http_service.dart';

part 'server_event.dart';
part 'server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  ServerBloc(this._httpService) : super(const ServerState()) {
    on<ServerStartRequested>(_onStartRequested);
  }

  final HttpService _httpService;

  Future<void> _onStartRequested(
    ServerStartRequested event,
    Emitter<ServerState> emit,
  ) async {
    emit(state.copyWith(status: ServerStatus.starting));
    try {
      await _httpService.start();
      appLogger.info('Server $kHttpPort-portda ishga tushdi');
      emit(state.copyWith(status: ServerStatus.running));
    } catch (e) {
      appLogger.severe('Server ishga tushmadi: $e');
      emit(
        state.copyWith(status: ServerStatus.error, errorMessage: e.toString()),
      );
    }
  }
}
