import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'dart:io';

// Contrat (interface abstraite) pour le service de communication.
// Ceci permet de découpler la logique métier de l'implémentation spécifique
// des protocoles réseau (WebSocket, gRPC).
// On pourra ainsi facilement mocker ce service pour les tests.
abstract class CommunicationService {

  // Établit la connexion avec le serveur desktop.
  Future<void> connect(String host, int port);

  // Ferme la connexion.
  Future<void> disconnect();

  // Obtient la liste des fichiers et dossiers pour un chemin donné sur l'ordinateur.
  Future<List<app_models.FileInfo>> listRemoteDirectory(String path);

  // Supprime un fichier ou dossier (récursif pour dossier si supporté).
  Future<bool> deleteRemote(String path);

  // Renomme ou déplace (mv) un fichier/dossier
  Future<bool> renameRemote({required String fromPath, required String toPath});

  // Envoie une commande générique au serveur (par exemple, pour la recherche).
  // Le type de retour sera défini plus précisément.
  Future<dynamic> sendCommand(String command, Map<String, dynamic> params);

  // Lance le téléchargement d'un fichier depuis l'ordinateur vers le smartphone.
  // Retourne un Stream pour suivre la progression.
  Stream<double> downloadFile(String remotePath, String localPath);

  // Lance l'envoi d'un fichier depuis le smartphone vers l'ordinateur.
  // Prend un objet File de dart:io. Il est nullable pour la simulation.
  // Retourne un Stream pour suivre la progression.
  Stream<double> uploadFile(File? file, String remotePath);

  // Lance l'envoi d'un dossier depuis le smartphone vers l'ordinateur.
  // Prend une liste de fichiers File de dart:io.
  // Retourne un Stream pour suivre la progression.
  Stream<double> uploadFolder(List<File> files, String remotePath);
}
