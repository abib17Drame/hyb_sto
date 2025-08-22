import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/settings/settings_event.dart';
import 'package:hybrid_storage_app/bloc/settings/settings_state.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/repositories/settings_repository.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _settingsRepository = getIt<SettingsRepository>();

  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleAutomaticTransfer>(_onToggleAutomaticTransfer);
    on<ChangeStorageThreshold>(_onChangeStorageThreshold);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final loadedState = await _settingsRepository.loadSettings();
      emit(loadedState.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onToggleAutomaticTransfer(
    ToggleAutomaticTransfer event,
    Emitter<SettingsState> emit,
  ) async {
    final newState = state.copyWith(isAutomaticTransferEnabled: event.isEnabled);
    emit(newState);
    await _settingsRepository.saveSettings(newState);
  }

  Future<void> _onChangeStorageThreshold(
    ChangeStorageThreshold event,
    Emitter<SettingsState> emit,
  ) async {
    final newState = state.copyWith(storageThreshold: event.threshold);
    emit(newState);
    await _settingsRepository.saveSettings(newState);
  }
}
