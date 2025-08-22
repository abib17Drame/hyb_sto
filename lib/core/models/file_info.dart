import 'package:equatable/equatable.dart';

// Énumération pour le type d'entité dans le système de fichiers.
enum FileType { file, directory }

// Modèle de données représentant un fichier ou un dossier.
// Ce modèle est utilisé à travers l'application pour manipuler les informations sur les fichiers.
// L'utilisation d'Equatable permet de comparer facilement des instances de FileInfo.
class FileInfo extends Equatable {
  final String name;
  final String path;
  final int sizeInBytes;
  final DateTime modifiedAt;
  final FileType type;
  final bool isLocal; // Vrai si le fichier est sur le smartphone, faux si sur l'ordinateur

  const FileInfo({
    required this.name,
    required this.path,
    required this.sizeInBytes,
    required this.modifiedAt,
    required this.type,
    required this.isLocal,
  });

  // Propriété calculée pour afficher la taille dans un format lisible.
  String get readableSize {
    if (type == FileType.directory) return ''; // Les dossiers n'ont pas de taille affichable ici.
    if (sizeInBytes < 1024) return '$sizeInBytes o';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} Ko';
    if (sizeInBytes < 1024 * 1024 * 1024) return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }

  @override
  List<Object?> get props => [path, name, modifiedAt, isLocal];

  // Factory constructor pour créer une instance depuis une Map (JSON)
  factory FileInfo.fromMap(Map<String, dynamic> map) {
    return FileInfo(
      name: map['nom'],
      path: map['chemin'],
      sizeInBytes: map['tailleOctets'],
      modifiedAt: DateTime.parse(map['modifieLe']),
      type: map['type'] == 'dossier' ? FileType.directory : FileType.file,
      isLocal: false, // On assume que les données de la map viennent du serveur
    );
  }
}
