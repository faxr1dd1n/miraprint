import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_constants.dart';
import '../../core/app_logger.dart';
import '../../service/arca/arca_bridge_server.dart';
import '../health/app_health.dart';

part 'arca_event.dart';
part 'arca_state.dart';

/// Arca ko'prigi (sayt <-> ERA terminali) serverining holati.
class ArcaBloc extends Bloc<ArcaEvent, ArcaState> {
  ArcaBloc(this._bridge) : super(const ArcaState()) {
    on<ArcaStartRequested>(_onStartRequested);
    on<ArcaStopped>(_onStopped);
    _bridge.onStopped = () => add(const ArcaStopped());
  }

  final ArcaBridgeServer _bridge;

  Future<void> _onStartRequested(
    ArcaStartRequested event,
    Emitter<ArcaState> emit,
  ) async {
    emit(state.copyWith(status: ArcaStatus.starting));
    try {
      await _bridge.start();
      appLogger.info('Arca server $kArcaPort-portda ishga tushdi');
      emit(state.copyWith(status: ArcaStatus.running));
    } catch (e) {
      appLogger.severe('Arca server ishga tushmadi: $e');
      emit(
        state.copyWith(status: ArcaStatus.error, errorMessage: e.toString()),
      );
    }
  }

  void _onStopped(ArcaStopped event, Emitter<ArcaState> emit) {
    emit(
      state.copyWith(
        status: ArcaStatus.error,
        errorMessage: kServerStoppedMessage,
      ),
    );
  }
}
