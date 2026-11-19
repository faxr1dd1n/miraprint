part of 'server_bloc.dart';

abstract class ServerEvent extends Equatable {
  const ServerEvent();

  @override
  List<Object?> get props => [];
}

class ServerStartRequested extends ServerEvent {
  const ServerStartRequested();
}

/// Ishga tushgandan keyin server javob bermay qolganida.
class ServerStopped extends ServerEvent {
  const ServerStopped();
}
