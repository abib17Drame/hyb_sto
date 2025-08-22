import 'package:equatable/equatable.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart';

// Fichier définissant les états de l'UI pour l'explorateur de fichiers.

abstract class FileExplorerState extends Equatable {
  const FileExplorerState();

  @override
  List<Object> get props => [];
}

// État initial, avant tout chargement.
class FileExplorerInitial extends FileExplorerState {}

// État de chargement, affiché pendant que les données sont récupérées.
class FileExplorerLoading extends FileExplorerState {}

// État de succès, lorsque les fichiers ont été chargés avec succès.
// Il contient la liste des fichiers à afficher.
class FileExplorerLoaded extends FileExplorerState {
  final List<FileInfo> files;
  final String currentPath;

  const FileExplorerLoaded({required this.files, required this.currentPath});

  @override
  List<Object> get props => [files, currentPath];
}

// État d'erreur, si un problème est survenu lors du chargement.
class FileExplorerError extends FileExplorerState {
  final String message;

  const FileExplorerError(this.message);

  @override
  List<Object> get props => [message];
}
