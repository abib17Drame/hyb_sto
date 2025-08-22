import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

// Événement pour charger les données du tableau de bord.
class LoadDashboardData extends DashboardEvent {}

// Événement pour rafraîchir les données.
class RefreshDashboardData extends DashboardEvent {}
