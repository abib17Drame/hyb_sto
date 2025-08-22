import 'package:hybrid_storage_app/bloc/settings/settings_state.dart';

// Contrat pour la persistance des paramètres.
abstract class SettingsRepository {

  // Charge les paramètres depuis le stockage local.
  Future<SettingsState> loadSettings();

  // Sauvegarde les paramètres dans le stockage local.
  Future<void> saveSettings(SettingsState state);
}
