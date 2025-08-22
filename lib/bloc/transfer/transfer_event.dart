import 'package:equatable/equatable.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;

// Fichier définissant les événements pour le TransferBloc.

abstract class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object> get props => [];
}

// Événement pour démarrer un nouveau transfert (upload).
class StartUpload extends TransferEvent {
  final app_models.FileInfo fileToUpload;
  final String remoteDestinationPath; // chemin distant cible

  const StartUpload(this.fileToUpload, this.remoteDestinationPath);

  @override
  List<Object> get props => [fileToUpload, remoteDestinationPath];
}

// Événement pour démarrer un nouveau téléchargement (download).
class StartDownload extends TransferEvent {
  final app_models.FileInfo fileToDownload;

  const StartDownload(this.fileToDownload);

  @override
  List<Object> get props => [fileToDownload];
}

// Événement interne pour mettre à jour la progression d'un transfert.
class UpdateTransferProgress extends TransferEvent {
  final String transferId;
  final double progress;

  const UpdateTransferProgress(this.transferId, this.progress);

  @override
  List<Object> get props => [transferId, progress];
}

// Événement interne pour marquer un transfert comme terminé.
class CompleteTransfer extends TransferEvent {
  final String transferId;

  const CompleteTransfer(this.transferId);

  @override
  List<Object> get props => [transferId];
}

// Événement interne pour marquer un transfert comme échoué.
class FailTransfer extends TransferEvent {
  final String transferId;
  final String errorMessage;

  const FailTransfer(this.transferId, this.errorMessage);

  @override
  List<Object> get props => [transferId, errorMessage];
}
