import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object> get props => [];
}

// Événement pour charger les paramètres sauvegardés.
class LoadSettings extends SettingsEvent {}

// Événement pour changer la valeur du transfert automatique.
class ToggleAutomaticTransfer extends SettingsEvent {
  final bool isEnabled;

  const ToggleAutomaticTransfer(this.isEnabled);

  @override
  List<Object> get props => [isEnabled];
}

// Événement pour changer le seuil de stockage.
class ChangeStorageThreshold extends SettingsEvent {
  final int threshold; // en pourcentage (ex: 10 pour 10%)

  const ChangeStorageThreshold(this.threshold);

  @override
  List<Object> get props => [threshold];
}
