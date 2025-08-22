import 'package:equatable/equatable.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'package:uuid/uuid.dart';

// Énumération pour le type de transfert.
enum TransferType { upload, download }

// Énumération pour le statut d'un transfert.
enum TransferStatus { ongoing, completed, failed }

// Modèle représentant un transfert de fichier.
class Transfer extends Equatable {
  final String id;
  final app_models.FileInfo file;
  final TransferType type;
  final TransferStatus status;
  final double progress; // Entre 0.0 et 1.0
  final String? errorMessage;
  final String? remoteDestinationPath; // chemin distant de destination

  Transfer({
    String? id,
    required this.file,
    required this.type,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.remoteDestinationPath,
  }) : id = id ?? const Uuid().v4();

  Transfer copyWith({
    TransferStatus? status,
    double? progress,
    String? errorMessage,
    String? remoteDestinationPath,
  }) {
    return Transfer(
      id: id,
      file: file,
      status: status ?? this.status,
      type: type,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      remoteDestinationPath: remoteDestinationPath ?? this.remoteDestinationPath,
    );
  }

  @override
  List<Object?> get props => [id, file, type, status, progress, errorMessage, remoteDestinationPath];
}

// L'état principal du BLoC des transferts.
// Il contient une liste de tous les transferts (en cours, terminés, etc.).
class TransferState extends Equatable {
  final List<Transfer> transfers;

  const TransferState({this.transfers = const []});

  // Sélecteurs pour facilement filtrer les listes pour l'UI.
  List<Transfer> get ongoingTransfers =>
      transfers.where((t) => t.status == TransferStatus.ongoing).toList();

  List<Transfer> get completedTransfers =>
      transfers.where((t) => t.status == TransferStatus.completed).toList();

  List<Transfer> get failedTransfers =>
      transfers.where((t) => t.status == TransferStatus.failed).toList();

  @override
  List<Object> get props => [transfers];

  TransferState copyWith({
    List<Transfer>? transfers,
  }) {
    return TransferState(
      transfers: transfers ?? this.transfers,
    );
  }
}
