import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/services/background_service.dart';
import 'package:hybrid_storage_app/core/services/real_communication_service.dart';
import 'package:http/http.dart' as http;

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final _secureStorage = const FlutterSecureStorage();
  final _backgroundService = getIt<BackgroundService>();

  // Clés pour le stockage sécurisé
  static const _keyDeviceId = 'id_appareil';
  static const _keyDevicePrivateKey = 'cle_privee_mobile';
  static const _keyServerPublicKey = 'cle_publique_serveur';
  static const _keyServerHost = 'serveur_host';
  static const _keyServerApiPort = 'serveur_api_port';
  static const _keyServerGrpcPort = 'serveur_grpc_port';

  // Vérifie le statut d'authentification au démarrage de l'application.
  Future<void> checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      // On vérifie si l'ID de l'appareil est sauvegardé. C'est notre indicateur d'appairage.
      final hasPairedDevice = await _secureStorage.containsKey(key: _keyDeviceId);

      if (hasPairedDevice) {
        // Reconfigure le service de communication avec les infos serveur si disponibles
        final host = await _secureStorage.read(key: _keyServerHost);
        final apiPortStr = await _secureStorage.read(key: _keyServerApiPort);
        final grpcPortStr = await _secureStorage.read(key: _keyServerGrpcPort);
        if (host != null && apiPortStr != null && grpcPortStr != null) {
          final comm = getIt<RealCommunicationService>();
          comm.configureServer(
            host: host,
            apiPort: int.tryParse(apiPortStr) ?? 8001,
            grpcPort: int.tryParse(grpcPortStr) ?? 50051,
          );
        }
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  // Méthode appelée après un appairage réussi.
  Future<void> devicePaired({
    required String idAppareil,
    required String clePriveeMobile,
    required String clePubliqueServeur,
    String? serveurHost,
    int? serveurApiPort,
    int? serveurGrpcPort,
  }) async {
    try {
      // Sauvegarde toutes les informations nécessaires à la connexion future.
      await _secureStorage.write(key: _keyDeviceId, value: idAppareil);
      await _secureStorage.write(key: _keyDevicePrivateKey, value: clePriveeMobile);
      await _secureStorage.write(key: _keyServerPublicKey, value: clePubliqueServeur);
      if (serveurHost != null) {
        await _secureStorage.write(key: _keyServerHost, value: serveurHost);
      }
      if (serveurApiPort != null) {
        await _secureStorage.write(key: _keyServerApiPort, value: serveurApiPort.toString());
      }
      if (serveurGrpcPort != null) {
        await _secureStorage.write(key: _keyServerGrpcPort, value: serveurGrpcPort.toString());
      }

      // Planifie la tâche de fond pour les transferts automatiques.
      await _backgroundService.schedulePeriodicCheck();

      emit(AuthAuthenticated());
    } catch (e) {
      // En cas d'erreur de sauvegarde, on ne considère pas l'appairage comme réussi.
      emit(AuthUnauthenticated());
    }
  }

  // Méthode pour se "déconnecter" (supprimer l'appairage).
  Future<void> unpairDevice() async {
    try {
      // Récupérer les informations de connexion avant de les supprimer
      final host = await _secureStorage.read(key: _keyServerHost);
      final apiPortStr = await _secureStorage.read(key: _keyServerApiPort);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      
      // Notifier le desktop que le mobile se déconnecte (si on a les infos)
      if (host != null && apiPortStr != null && deviceId != null) {
        try {
          final apiPort = int.tryParse(apiPortStr) ?? 8001;
          final response = await http.delete(
            Uri.parse('http://$host:$apiPort/api/v1/appareils/$deviceId'),
          );
          print('[UNPAIR] Notification envoyée au desktop: ${response.statusCode}');
        } catch (e) {
          print('[UNPAIR] Erreur lors de la notification au desktop: $e');
          // Continue même si la notification échoue
        }
      }
    } catch (e) {
      print('[UNPAIR] Erreur lors de la récupération des infos: $e');
    }

    // Supprimer les données locales
    await _secureStorage.delete(key: _keyDeviceId);
    await _secureStorage.delete(key: _keyDevicePrivateKey);
    await _secureStorage.delete(key: _keyServerPublicKey);
    await _secureStorage.delete(key: _keyServerHost);
    await _secureStorage.delete(key: _keyServerApiPort);
    await _secureStorage.delete(key: _keyServerGrpcPort);

    // Annule les tâches de fond planifiées.
    await _backgroundService.cancelAllTasks();

    emit(AuthUnauthenticated());
  }

  // Méthode pour se déconnecter silencieusement (sans notifier le desktop)
  // Utilisée quand le desktop a déjà révoqué l'appareil
  Future<void> unpairDeviceSilently() async {
    // Supprimer les données locales
    await _secureStorage.delete(key: _keyDeviceId);
    await _secureStorage.delete(key: _keyDevicePrivateKey);
    await _secureStorage.delete(key: _keyServerPublicKey);
    await _secureStorage.delete(key: _keyServerHost);
    await _secureStorage.delete(key: _keyServerApiPort);
    await _secureStorage.delete(key: _keyServerGrpcPort);

    // Annule les tâches de fond planifiées.
    await _backgroundService.cancelAllTasks();

    emit(AuthUnauthenticated());
  }
}
