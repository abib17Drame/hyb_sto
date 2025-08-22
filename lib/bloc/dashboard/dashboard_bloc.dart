import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/dashboard/dashboard_event.dart';
import 'package:hybrid_storage_app/bloc/dashboard/dashboard_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/services/real_communication_service.dart';
import 'package:flutter/services.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  // TODO: Injecter un service qui peut fournir ces statistiques.
  // final StatsService _statsService = getIt<StatsService>();

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadData);
    on<RefreshDashboardData>(_onLoadData); // Le rafraîchissement recharge les données
  }

  Future<void> _onLoadData(
    DashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      // Récupère l'IP/ports courants configurés dans le service
      final comm = getIt.get<RealCommunicationService>();
      // Appelle le backend desktop pour obtenir les statistiques réelles
      final uri = Uri.parse('http://${comm.host}:${comm.apiPort}/api/v1/stockage/statistiques');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('Code HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final stockage = data['stockage'] as Map<String, dynamic>;
      final remote = StorageStats(
        totalSpaceGB: (stockage['totalGo'] as num?)?.toDouble() ?? 0.0,
        usedSpaceGB: (stockage['utiliseGo'] as num?)?.toDouble() ?? 0.0,
      );
      // Local: appelle le MethodChannel Android/iOS pour l'espace disque
      final localTotal = await _getTotalSpaceGB();
      final localFree = await _getFreeSpaceGB();
      final local = StorageStats(
        totalSpaceGB: localTotal ?? 0.0,
        usedSpaceGB: (localTotal != null && localFree != null) ? (localTotal - localFree) : 0.0,
      );

      emit(DashboardLoaded(
        localStats: local,
        remoteStats: remote,
        recentTransfersCount: 0,
      ));
    } catch (e) {
      emit(DashboardError('Erreur lors du chargement des données: ${e.toString()}'));
    }
  }
}

// Helpers MethodChannel pour l'espace disque local
const MethodChannel _diskChannel = MethodChannel('hybrid_storage_app/disk_space');

Future<double?> _getTotalSpaceGB() async {
  try {
    final value = await _diskChannel.invokeMethod('getTotalDiskSpaceGB');
    if (value is double) return value;
    if (value is num) return value.toDouble();
  } catch (_) {}
  return null;
}

Future<double?> _getFreeSpaceGB() async {
  try {
    final value = await _diskChannel.invokeMethod('getFreeDiskSpaceGB');
    if (value is double) return value;
    if (value is num) return value.toDouble();
  } catch (_) {}
  return null;
}
