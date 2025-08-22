import 'package:get_it/get_it.dart';
import 'package:hybrid_storage_app/core/repositories/settings_repository.dart';
import 'package:hybrid_storage_app/core/repositories/shared_prefs_settings_repository.dart';
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:hybrid_storage_app/core/services/crypto_service.dart';
import 'package:hybrid_storage_app/core/services/background_service.dart';
import 'package:hybrid_storage_app/core/services/real_communication_service.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_bloc.dart';
import 'package:hybrid_storage_app/bloc/file_explorer/file_explorer_bloc.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_cubit.dart';

// Instance globale du localisateur de services.
final getIt = GetIt.instance;

// Fonction pour configurer et enregistrer les services.
void setupLocator() {
  // Enregistre une seule instance réelle et l'expose via l'interface
  getIt.registerLazySingleton<RealCommunicationService>(() => RealCommunicationService());
  getIt.registerLazySingleton<CommunicationService>(() => getIt<RealCommunicationService>());

  // Enregistre le repository des paramètres avec la vraie implémentation.
  getIt.registerLazySingleton<SettingsRepository>(() => SharedPrefsSettingsRepository());

  // Enregistre le service de cryptographie.
  getIt.registerLazySingleton<CryptoService>(() => CryptoService());

  // Enregistre le service de tâches de fond.
  getIt.registerLazySingleton<BackgroundService>(() => BackgroundService());

  // Enregistre les BLoCs comme singletons pour persister l'état
  getIt.registerLazySingleton<TransferBloc>(() => TransferBloc());
  getIt.registerLazySingleton<FileExplorerBloc>(() => FileExplorerBloc());
  getIt.registerLazySingleton<AuthCubit>(() => AuthCubit());
}
