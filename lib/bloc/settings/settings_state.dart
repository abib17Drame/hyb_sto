import 'package:equatable/equatable.dart';

// L'état qui contient toutes les configurations de l'application.
class SettingsState extends Equatable {
  final bool isAutomaticTransferEnabled;
  final int storageThreshold; // en pourcentage
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.isAutomaticTransferEnabled = true,
    this.storageThreshold = 10,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    bool? isAutomaticTransferEnabled,
    int? storageThreshold,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      isAutomaticTransferEnabled: isAutomaticTransferEnabled ?? this.isAutomaticTransferEnabled,
      storageThreshold: storageThreshold ?? this.storageThreshold,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isAutomaticTransferEnabled, storageThreshold, isLoading, error];
}
