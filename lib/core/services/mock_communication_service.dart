import 'dart:async';
import 'dart:io';

import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'package:hybrid_storage_app/core/services/communication_service.dart';

// Implémentation mock du service de communication pour les tests et le développement.
class MockCommunicationService implements CommunicationService {
  @override
  Future<void> connect(String host, int port) async {
    // Simule un délai de connexion
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> disconnect() async {
    // Simule un délai de déconnexion
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<List<app_models.FileInfo>> listRemoteDirectory(String path) async {
    // Simule un délai de récupération
    await Future.delayed(const Duration(milliseconds: 800));

    // Retourne des données fictives
    return [
      app_models.FileInfo(
        name: 'document.pdf',
        path: '$path/document.pdf',
        sizeInBytes: 1024 * 1024, // 1 MB
        modifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
        type: app_models.FileType.file,
        isLocal: false,
      ),
      app_models.FileInfo(
        name: 'images',
        path: '$path/images',
        sizeInBytes: 0,
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
        type: app_models.FileType.directory,
        isLocal: false,
      ),
      app_models.FileInfo(
        name: 'rapport.docx',
        path: '$path/rapport.docx',
        sizeInBytes: 512 * 1024, // 512 KB
        modifiedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        type: app_models.FileType.file,
        isLocal: false,
      ),
    ];
  }

  @override
  Future<bool> deleteRemote(String path) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // Simule une suppression réussie
  }

  @override
  Future<bool> renameRemote({required String fromPath, required String toPath}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true; // Simule un renommage réussi
  }

  @override
  Future sendCommand(String command, Map<String, dynamic> params) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'status': 'success', 'data': 'Mock response'};
  }

  @override
  Stream<double> downloadFile(String remotePath, String localPath) {
    return Stream.periodic(
      const Duration(milliseconds: 100),
      (count) {
        final progress = (count * 0.1).clamp(0.0, 1.0);
        if (progress >= 1.0) {
          return 1.0;
        }
        return progress;
      },
    ).take(11); // 11 valeurs: 0.0, 0.1, 0.2, ..., 1.0
  }

  @override
  Stream<double> uploadFile(File? file, String remotePath) {
    if (file == null) return Stream.value(0.0);
    
    return Stream.periodic(
      const Duration(milliseconds: 150),
      (count) {
        final progress = (count * 0.15).clamp(0.0, 1.0);
        if (progress >= 1.0) {
          return 1.0;
        }
        return progress;
      },
    ).take(8); // 8 valeurs pour simuler un upload plus rapide
  }

  @override
  Stream<double> uploadFolder(List<File> files, String remotePath) {
    if (files.isEmpty) return Stream.value(0.0);
    
    return Stream.periodic(
      const Duration(milliseconds: 200),
      (count) {
        final progress = (count * 0.1).clamp(0.0, 1.0);
        if (progress >= 1.0) {
          return 1.0;
        }
        return progress;
      },
    ).take(11); // 11 valeurs pour simuler un upload de dossier
  }
}
