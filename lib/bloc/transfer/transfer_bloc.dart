import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_event.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_state.dart';
import 'package:hybrid_storage_app/bloc/file_explorer/file_explorer_bloc.dart';
import 'package:hybrid_storage_app/bloc/file_explorer/file_explorer_event.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final CommunicationService _communicationService = getIt<CommunicationService>();
  // Liste pour garder une référence à toutes les souscriptions de stream actives.
  final List<StreamSubscription> _subscriptions = [];

  TransferBloc() : super(const TransferState()) {
    on<StartDownload>(_onStartDownload);
    on<StartUpload>(_onStartUpload);
    on<UpdateTransferProgress>(_onUpdateProgress);
    on<CompleteTransfer>(_onCompleteTransfer);
    on<FailTransfer>(_onFailTransfer);
  }

  void _onStartDownload(StartDownload event, Emitter<TransferState> emit) {
    final newTransfer = Transfer(
      file: event.fileToDownload,
      status: TransferStatus.ongoing,
      type: TransferType.download,
    );
    _initiateTransfer(newTransfer, emit);
  }

  void _onStartUpload(StartUpload event, Emitter<TransferState> emit) {
    final newTransfer = Transfer(
      file: event.fileToUpload,
      status: TransferStatus.ongoing,
      type: TransferType.upload,
      remoteDestinationPath: event.remoteDestinationPath,
    );
    _initiateTransfer(newTransfer, emit);
  }

  void _initiateTransfer(Transfer transfer, Emitter<TransferState> emit) {
    final updatedTransfers = List<Transfer>.from(state.transfers)..add(transfer);
    emit(state.copyWith(transfers: updatedTransfers));

    Stream<double> progressStream;
    if (transfer.type == TransferType.download) {
      // TODO: fournir un vrai chemin local via un sélecteur de fichier
      progressStream = _communicationService.downloadFile(transfer.file.path, '/storage/emulated/0/Download/${transfer.file.name}');
    } else {
      // Upload - utiliser le vrai fichier depuis le FileInfo
      if (transfer.file.isLocal) {
        if (transfer.file.type == app_models.FileType.directory) {
          // Pour les dossiers, récupérer tous les fichiers et utiliser uploadFolder
          _uploadDirectory(transfer, emit);
          return; // On sort car on gère l'upload de dossier séparément
        } else {
          // Pour les fichiers individuels
          final file = File(transfer.file.path);
          final remotePath = transfer.remoteDestinationPath ?? '/';
          progressStream = _communicationService.uploadFile(file, remotePath);
        }
      } else {
        progressStream = _communicationService.uploadFile(null, transfer.file.path);
      }
    }

    // On stocke la souscription pour pouvoir l'annuler plus tard.
    final subscription = progressStream.listen(
      (progress) {
        if (!isClosed) add(UpdateTransferProgress(transfer.id, progress));
      },
      onDone: () {
        if (!isClosed) add(CompleteTransfer(transfer.id));
      },
      onError: (error) {
        if (!isClosed) add(FailTransfer(transfer.id, error.toString()));
      },
    );
    _subscriptions.add(subscription);
  }

  // Méthode pour s'assurer que le dossier de destination existe
  Future<void> _ensureDestinationDirectory(String path) async {
    try {
      // Envoyer une commande pour créer le dossier s'il n'existe pas
      await _communicationService.sendCommand('create_directory', {'path': path});
    } catch (e) {
      // Ignorer les erreurs, le serveur gérera la création automatiquement
      print('Impossible de créer le dossier de destination: $e');
    }
  }

  void _uploadDirectory(Transfer transfer, Emitter<TransferState> emit) async {
    try {
      final directory = Directory(transfer.file.path);
      final files = <File>[];
      
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          files.add(entity);
        }
      }
      
      if (files.isNotEmpty) {
        final remotePath = transfer.remoteDestinationPath ?? '/';
        final progressStream = _communicationService.uploadFolder(files, remotePath);
        
        final subscription = progressStream.listen(
          (progress) {
            if (!isClosed) add(UpdateTransferProgress(transfer.id, progress));
          },
          onDone: () {
            if (!isClosed) add(CompleteTransfer(transfer.id));
          },
          onError: (error) {
            if (!isClosed) add(FailTransfer(transfer.id, error.toString()));
          },
        );
        _subscriptions.add(subscription);
      } else {
        // Dossier vide
        add(CompleteTransfer(transfer.id));
      }
    } catch (e) {
      add(FailTransfer(transfer.id, e.toString()));
    }
  }

  void _onUpdateProgress(
    UpdateTransferProgress event,
    Emitter<TransferState> emit,
  ) {
    final updatedTransfers = state.transfers.map((transfer) {
      if (transfer.id == event.transferId) {
        return transfer.copyWith(progress: event.progress);
      }
      return transfer;
    }).toList();

    emit(state.copyWith(transfers: updatedTransfers));
  }

  void _onCompleteTransfer(
    CompleteTransfer event,
    Emitter<TransferState> emit,
  ) {
    final updatedTransfers = state.transfers.map((transfer) {
      if (transfer.id == event.transferId) {
        return transfer.copyWith(status: TransferStatus.completed, progress: 1.0);
      }
      return transfer;
    }).toList();

    emit(state.copyWith(transfers: updatedTransfers));
    
    // Rafraîchir l'explorateur de fichiers après un transfert réussi
    _refreshFileExplorer();
    
    // Afficher une notification de succès
    final completedTransfer = updatedTransfers.firstWhere((t) => t.id == event.transferId);
    if (completedTransfer.type == TransferType.upload) {
      final destination = completedTransfer.remoteDestinationPath ?? '/';
      print('[SUCCESS] Fichier "${completedTransfer.file.name}" envoyé avec succès vers $destination');
    }
  }

  void _onFailTransfer(FailTransfer event, Emitter<TransferState> emit) {
    final updatedTransfers = state.transfers.map((transfer) {
      if (transfer.id == event.transferId) {
        return transfer.copyWith(status: TransferStatus.failed, errorMessage: event.errorMessage);
      }
      return transfer;
    }).toList();

    emit(state.copyWith(transfers: updatedTransfers));
  }

  // Méthode pour rafraîchir l'explorateur de fichiers
  void _refreshFileExplorer() {
    try {
      // Récupérer le FileExplorerBloc depuis le service locator
      final fileExplorerBloc = getIt<FileExplorerBloc>();
      // Rafraîchir le répertoire actuel
      fileExplorerBloc.add(LoadDirectory('/'));
    } catch (e) {
      // Ignorer les erreurs si le FileExplorerBloc n'est pas disponible
      print('Impossible de rafraîchir l\'explorateur de fichiers: $e');
    }
  }

  // On surcharge la méthode `close` du BLoC.
  @override
  Future<void> close() {
    // On annule chaque souscription active pour éviter les fuites de mémoire et les erreurs.
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    // On appelle la méthode `close` de la classe parente pour terminer le nettoyage.
    return super.close();
  }
}
