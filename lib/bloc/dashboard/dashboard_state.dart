import 'package:equatable/equatable.dart';

// Modèle pour les statistiques de stockage.
class StorageStats extends Equatable {
  final double totalSpaceGB;
  final double usedSpaceGB;

  const StorageStats({required this.totalSpaceGB, required this.usedSpaceGB});

  double get freeSpaceGB => totalSpaceGB - usedSpaceGB;
  double get usagePercentage {
    if (totalSpaceGB <= 0) return 0.0;
    final ratio = usedSpaceGB / totalSpaceGB;
    if (ratio.isNaN || ratio.isInfinite) return 0.0;
    final clamped = ratio.clamp(0.0, 1.0);
    return clamped is double ? clamped : (clamped as num).toDouble();
  }

  @override
  List<Object> get props => [totalSpaceGB, usedSpaceGB];
}

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final StorageStats localStats;
  final StorageStats remoteStats;
  final int recentTransfersCount;

  const DashboardLoaded({
    required this.localStats,
    required this.remoteStats,
    required this.recentTransfersCount,
  });

  @override
  List<Object> get props => [localStats, remoteStats, recentTransfersCount];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
