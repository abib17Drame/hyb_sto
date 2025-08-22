import 'package:equatable/equatable.dart';

// Fichier définissant les événements que l'UI peut envoyer au FileExplorerBloc.

abstract class FileExplorerEvent extends Equatable {
  const FileExplorerEvent();

  @override
  List<Object> get props => [];
}

// Événement pour charger le contenu d'un répertoire.
// Le chemin (path) peut être celui du répertoire racine ou d'un sous-dossier.
class LoadDirectory extends FileExplorerEvent {
  final String path;

  const LoadDirectory(this.path);

  @override
  List<Object> get props => [path];
}

// Événement pour rafraîchir le contenu du répertoire actuel.
class RefreshDirectory extends FileExplorerEvent {}

// Événement pour rechercher des fichiers.
class SearchFiles extends FileExplorerEvent {
  final String query;

  const SearchFiles(this.query);

  @override
  List<Object> get props => [query];
}

// Événement pour trier les fichiers affichés.
enum SortCriterion { name, date, size }

class SortFiles extends FileExplorerEvent {
  final SortCriterion criterion;

  const SortFiles(this.criterion);

  @override
  List<Object> get props => [criterion];
}

// Événement pour supprimer un fichier ou dossier
class DeleteFile extends FileExplorerEvent {
  final String path;

  const DeleteFile(this.path);

  @override
  List<Object> get props => [path];
}

// Événement pour renommer un fichier ou dossier
class RenameFile extends FileExplorerEvent {
  final String fromPath;
  final String toPath;

  const RenameFile({required this.fromPath, required this.toPath});

  @override
  List<Object> get props => [fromPath, toPath];
}
