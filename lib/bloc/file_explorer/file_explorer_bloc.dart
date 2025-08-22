import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/file_explorer/file_explorer_event.dart';
import 'package:hybrid_storage_app/bloc/file_explorer/file_explorer_state.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_cubit.dart';

class FileExplorerBloc extends Bloc<FileExplorerEvent, FileExplorerState> {
  final CommunicationService _communicationService = getIt<CommunicationService>();

  FileExplorerBloc() : super(FileExplorerInitial()) {
    on<LoadDirectory>(_onLoadDirectory);
    on<SortFiles>(_onSortFiles);
    on<SearchFiles>(_onSearchFiles);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);
  }

  Future<void> _onLoadDirectory(
    LoadDirectory event,
    Emitter<FileExplorerState> emit,
  ) async {
    emit(FileExplorerLoading());
    try {
      final files = await _communicationService.listRemoteDirectory(event.path);
      emit(FileExplorerLoaded(files: files, currentPath: event.path));
    } catch (e) {
      print('[FILE EXPLORER ERROR] $e');
      // Vérifier si l'erreur est liée à la révocation
      if (e.toString().contains('403') || 
          e.toString().contains('was not upgraded to websocket') ||
          e.toString().contains('Aucun identifiant d\'appareil trouvé')) {
        print('[REVOCATION DETECTED] Appareil révoqué, déconnexion...');
        // Notifier l'AuthCubit pour gérer la déconnexion
        // Mais seulement si on n'est pas déjà en train de se déconnecter
        try {
          final authCubit = getIt<AuthCubit>();
          authCubit.unpairDeviceSilently();
        } catch (e) {
          print('[REVOCATION] Erreur lors de la déconnexion: $e');
        }
        return;
      }
      emit(FileExplorerError('Impossible de charger le répertoire: ${e.toString()}'));
    }
  }

  void _onSortFiles(SortFiles event, Emitter<FileExplorerState> emit) {
    if (state is FileExplorerLoaded) {
      final currentState = state as FileExplorerLoaded;
      final List<app_models.FileInfo> files = List.from(currentState.files);

      // Tri des fichiers en fonction du critère.
      files.sort((a, b) {
        switch (event.criterion) {
          case SortCriterion.name:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case SortCriterion.date:
            return b.modifiedAt.compareTo(a.modifiedAt); // plus récent en premier
          case SortCriterion.size:
            return b.sizeInBytes.compareTo(a.sizeInBytes); // plus gros en premier
        }
      });

      emit(FileExplorerLoaded(files: files, currentPath: currentState.currentPath));
    }
  }

  Future<void> _onSearchFiles(
    SearchFiles event,
    Emitter<FileExplorerState> emit,
  ) async {
    emit(FileExplorerLoading());
    try {
      // Simule une recherche. Dans une vraie app, on appellerait un endpoint de recherche.
      await Future.delayed(const Duration(milliseconds: 500));
      final allFiles = await _communicationService.listRemoteDirectory('/');
      final results = allFiles
          .where((file) => file.name.toLowerCase().contains(event.query.toLowerCase()))
          .toList();
      emit(FileExplorerLoaded(files: results, currentPath: 'Résultats de recherche'));
    } catch (e) {
      print('[FILE EXPLORER SEARCH ERROR] $e');
      // Vérifier si l'erreur est liée à la révocation
      if (e.toString().contains('403') || 
          e.toString().contains('was not upgraded to websocket') ||
          e.toString().contains('Aucun identifiant d\'appareil trouvé')) {
        print('[REVOCATION DETECTED] Appareil révoqué, déconnexion...');
        // Notifier l'AuthCubit pour gérer la déconnexion
        // Mais seulement si on n'est pas déjà en train de se déconnecter
        try {
          final authCubit = getIt<AuthCubit>();
          authCubit.unpairDeviceSilently();
        } catch (e) {
          print('[REVOCATION] Erreur lors de la déconnexion: $e');
        }
        return;
      }
      emit(FileExplorerError('Erreur de recherche: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteFile(
    DeleteFile event,
    Emitter<FileExplorerState> emit,
  ) async {
    try {
      final success = await _communicationService.deleteRemote(event.path);
      if (success) {
        // Rafraîchir le répertoire actuel après suppression
        if (state is FileExplorerLoaded) {
          final currentState = state as FileExplorerLoaded;
          add(LoadDirectory(currentState.currentPath));
        }
      } else {
        emit(FileExplorerError('Impossible de supprimer le fichier'));
      }
    } catch (e) {
      emit(FileExplorerError('Erreur lors de la suppression: ${e.toString()}'));
    }
  }

  Future<void> _onRenameFile(
    RenameFile event,
    Emitter<FileExplorerState> emit,
  ) async {
    try {
      final success = await _communicationService.renameRemote(
        fromPath: event.fromPath,
        toPath: event.toPath,
      );
      if (success) {
        // Rafraîchir le répertoire actuel après renommage
        if (state is FileExplorerLoaded) {
          final currentState = state as FileExplorerLoaded;
          add(LoadDirectory(currentState.currentPath));
        }
      } else {
        emit(FileExplorerError('Impossible de renommer le fichier'));
      }
    } catch (e) {
      emit(FileExplorerError('Erreur lors du renommage: ${e.toString()}'));
    }
  }
}
