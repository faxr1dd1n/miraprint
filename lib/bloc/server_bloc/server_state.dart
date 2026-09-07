part of 'server_bloc.dart';

enum ServerStatus { initial, starting, running, error }

class ServerState extends Equatable {
  const ServerState({this.status = ServerStatus.initial, this.errorMessage});

  final ServerStatus status;
  final String? errorMessage;

  ServerState copyWith({ServerStatus? status, String? errorMessage}) {
    return ServerState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
