part of 'arca_bloc.dart';

enum ArcaStatus { initial, starting, running, error }

class ArcaState extends Equatable {
  const ArcaState({this.status = ArcaStatus.initial, this.errorMessage});

  final ArcaStatus status;
  final String? errorMessage;

  ArcaState copyWith({ArcaStatus? status, String? errorMessage}) {
    return ArcaState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
