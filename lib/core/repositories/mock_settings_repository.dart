import 'package:hybrid_storage_app/bloc/settings/settings_state.dart';
import 'package:hybrid_storage_app/core/repositories/settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  SettingsState _currentState = const SettingsState();

  @override
  Future<SettingsState> loadSettings() async {
    // Simule la lecture depuis le disque.
    await Future.delayed(const Duration(milliseconds: 200));
    print('MockSettingsRepository: Loaded settings: $_currentState');
    return _currentState;
  }

  @override
  Future<void> saveSettings(SettingsState state) async {
    // Simule l'écriture sur le disque.
    await Future.delayed(const Duration(milliseconds: 200));
    _currentState = state;
    print('MockSettingsRepository: Saved settings: $_currentState');
  }
}
