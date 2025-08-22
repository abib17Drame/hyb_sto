import 'package:hybrid_storage_app/bloc/settings/settings_state.dart';
import 'package:hybrid_storage_app/core/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Implémentation réelle du repository des paramètres utilisant SharedPreferences.
class SharedPrefsSettingsRepository implements SettingsRepository {
  // Clés pour le stockage
  static const _keyAutomaticTransfer = 'param_transfert_auto';
  static const _keyStorageThreshold = 'param_seuil_stockage';

  @override
  Future<SettingsState> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Lit les valeurs depuis le stockage, avec des valeurs par défaut si elles n'existent pas.
    final bool isAutoTransferEnabled = prefs.getBool(_keyAutomaticTransfer) ?? true;
    final int threshold = prefs.getInt(_keyStorageThreshold) ?? 10;

    return SettingsState(
      isAutomaticTransferEnabled: isAutoTransferEnabled,
      storageThreshold: threshold,
    );
  }

  @override
  Future<void> saveSettings(SettingsState state) async {
    final prefs = await SharedPreferences.getInstance();

    // Sauvegarde les valeurs dans le stockage persistant.
    await prefs.setBool(_keyAutomaticTransfer, state.isAutomaticTransferEnabled);
    await prefs.setInt(_keyStorageThreshold, state.storageThreshold);
  }
}
