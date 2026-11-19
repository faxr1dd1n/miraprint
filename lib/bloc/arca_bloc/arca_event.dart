part of 'arca_bloc.dart';

abstract class ArcaEvent extends Equatable {
  const ArcaEvent();

  @override
  List<Object?> get props => [];
}

class ArcaStartRequested extends ArcaEvent {
  const ArcaStartRequested();
}

/// Ishga tushgandan keyin server kutilmaganda to'xtab qolganida.
class ArcaStopped extends ArcaEvent {
  const ArcaStopped();
}
