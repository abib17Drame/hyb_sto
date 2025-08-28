import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:hybrid_storage_app/core/services/grpc/transfer.pbgrpc.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_cubit.dart';

class RealCommunicationService implements CommunicationService {
  IOWebSocketChannel? _channel;
  StreamController<List<app_models.FileInfo>>? _fileListController;
  FileTransferClient? _grpcClient;
  ClientChannel? _grpcChannel;
  String? _deviceId;

  String _host = "127.0.0.1";
  int _apiPort = 8001; // FastAPI desktop écoute par défaut sur 8001
  int _grpcPort = 50051;

  // Expose les paramètres courants (lecture seule)
  String get host => _host;
  int get apiPort => _apiPort;
  int get grpcPort => _grpcPort;

  void configureServer({required String host, required int apiPort, required int grpcPort}) {
    _host = host;
    _apiPort = apiPort;
    _grpcPort = grpcPort;
    // Réinitialiser complètement les canaux pour la nouvelle config
    _channel?.sink.close();
    _channel = null;
    _fileListController?.close();
    _fileListController = null;
    _grpcClient = null;
    _grpcChannel?.shutdown();
    _grpcChannel = null;
    // Réinitialiser l'ID d'appareil pour forcer un nouveau chargement
    _deviceId = null;
  }

  Future<String?> _loadDeviceId() async {
    if (_deviceId != null) return _deviceId;
    const storage = FlutterSecureStorage();
    _deviceId = await storage.read(key: 'id_appareil');
    return _deviceId;
  }

  // Méthode pour initialiser les connexions
  Future<void> _init() async {
    if (_channel == null) {
      final String? idAppareil = await _loadDeviceId();
      if (idAppareil == null) {
        throw StateError('Aucun identifiant d\'appareil trouvé. Veuillez appairer le mobile.');
      }
      final url = Uri.parse('ws://$_host:$_apiPort/ws/$idAppareil');
      try {
        _channel = IOWebSocketChannel.connect(url);
        _fileListController = StreamController<List<app_models.FileInfo>>.broadcast();
        _listenToWebSocket();
      } catch (e) {
        print('[WEBSOCKET CONNECTION ERROR] $e');
        // Si la connexion échoue (403, appareil révoqué), gérer la révocation
        if (e.toString().contains('403') || 
            e.toString().contains('was not upgraded to websocket')) {
          print('[REVOCATION] Connexion WebSocket échouée - appareil probablement révoqué');
          // Nettoyer immédiatement pour éviter les boucles
          _channel?.sink.close();
          _channel = null;
          _fileListController?.close();
          _fileListController = null;
          _deviceId = null;
          _handleRevocation();
          return;
        }
        rethrow;
      }
    }
    if (_grpcClient == null) {
      _grpcChannel = ClientChannel(
        _host,
        port: _grpcPort,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
      );
      _grpcClient = FileTransferClient(_grpcChannel!);
    }
  }

  void _listenToWebSocket() {
    _channel?.stream.listen((message) {
      final decodedMessage = jsonDecode(message);
      if (decodedMessage['action'] == 'liste_fichiers' && decodedMessage['statut'] == 'succes') {
        final List<dynamic> contenu = decodedMessage['donnees']['contenu'];
        // Utilise maintenant le factory constructor
        final files = contenu.map((data) => app_models.FileInfo.fromMap(data)).toList();
        _fileListController?.add(files);
      } else if (decodedMessage['action'] == 'revoked') {
        // Gestion de la révocation - déconnecter et nettoyer
        print('[REVOCATION] Appareil révoqué par le serveur');
        _handleRevocation();
      }
    }, onError: (error) {
      print('[WEBSOCKET ERROR] $error');
      // En cas d'erreur de connexion, vérifier si c'est une révocation
      if (error.toString().contains('4003') || 
          error.toString().contains('403') ||
          error.toString().contains('was not upgraded to websocket')) {
        print('[REVOCATION] Erreur de connexion détectée - appareil probablement révoqué');
        _handleRevocation();
      }
    }, onDone: () {
      print('[WEBSOCKET] Connexion fermée');
    });
  }

  void _handleRevocation() {
    // Nettoyer les connexions
    _channel?.sink.close();
    _channel = null;
    _fileListController?.close();
    _fileListController = null;
    _grpcClient = null;
    _grpcChannel?.shutdown();
    _grpcChannel = null;
    // Réinitialiser l'ID d'appareil pour éviter les boucles
    _deviceId = null;
    
    // Notifier l'AuthCubit pour qu'il gère la déconnexion
    // Mais sans notifier le desktop (éviter la boucle)
    final authCubit = getIt<AuthCubit>();
    authCubit.unpairDeviceSilently();
  }

  @override
  Future<void> connect(String host, int port) async {
    await _init();
  }

  @override
  Future<void> disconnect() async {
    _channel?.sink.close();
    _fileListController?.close();
    await _grpcChannel?.shutdown();
  }

  @override
  Future<List<app_models.FileInfo>> listRemoteDirectory(String path) async {
    try {
      await _init();
      final command = {"action": "lister_fichiers", "charge_utile": {"chemin": path}};
      _channel?.sink.add(jsonEncode(command));
      return await _fileListController!.stream.first;
    } catch (e) {
      print('[LIST DIRECTORY ERROR] $e');
      // Si l'erreur est liée à la révocation, nettoyer et laisser _handleRevocation() s'en occuper
      if (e.toString().contains('403') || 
          e.toString().contains('was not upgraded to websocket') ||
          e.toString().contains('Aucun identifiant d\'appareil trouvé')) {
        // Nettoyer immédiatement pour éviter les boucles
        _channel?.sink.close();
        _channel = null;
        _fileListController?.close();
        _fileListController = null;
        _deviceId = null;
        rethrow;
      }
      // Pour les autres erreurs, retourner une liste vide
      return [];
    }
  }

  @override
  Stream<double> downloadFile(String remotePath, String localPath) {
    _init();
    final controller = StreamController<double>();
    () async {
      final request = DownloadRequest()..remoteFilePath = remotePath;
      final responseStream = _grpcClient!.downloadFile(request);
      final file = File(localPath);
      await file.create(recursive: true);
      final sink = file.openWrite();
      try {
        await for (final chunk in responseStream) {
          sink.add(chunk.content);
          // Émet une valeur pour indiquer l'activité (progression indéterminée)
          controller.add(0.0);
        }
        await sink.close();
        controller.add(1.0);
        await controller.close();
      } catch (e) {
        await sink.close();
        controller.addError(e);
        await controller.close();
      }
    }();
    return controller.stream;
  }

  @override
  Stream<double> uploadFile(File? file, String remotePath) {
    final controller = StreamController<double>();
    
    () async {
      try {
        print('[DEBUG UPLOAD] Début upload fichier');
        print('[DEBUG UPLOAD] file=${file?.path}');
        print('[DEBUG UPLOAD] remotePath=$remotePath');
        print('[DEBUG UPLOAD] host=$_host, port=$_apiPort');
        
        if (file == null) {
          print('[ERREUR] Fichier null');
          controller.addError('Fichier null');
          await controller.close();
          return;
        }

        if (!await file.exists()) {
          print('[ERREUR] Fichier n\'existe pas: ${file.path}');
          controller.addError('Fichier n\'existe pas');
          await controller.close();
          return;
        }

        final fileSize = await file.length();
        print('[DEBUG UPLOAD] Taille du fichier: $fileSize bytes');

        // Utiliser HTTP pour l'upload
        final uri = Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/upload');
        print('[DEBUG UPLOAD] URI: $uri');
        
        final request = http.MultipartRequest('POST', uri);
        
        // Ajouter le paramètre de chemin de destination
        request.fields['chemin_destination'] = remotePath;
        print('[DEBUG UPLOAD] chemin_destination=$remotePath');
        
        // Ajouter le fichier
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: file.path.split('/').last,
        );
        request.files.add(multipartFile);
        
        print('[DEBUG UPLOAD] Envoi de la requête...');
        
        // Créer le dossier de destination avant l'upload
        try {
          final createDirResponse = await http.post(
            Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/creer-dossier'),
            body: {'chemin': remotePath},
          );
          print('[DEBUG UPLOAD] Création dossier - Status: ${createDirResponse.statusCode}');
        } catch (e) {
          print('[WARNING] Impossible de créer le dossier: $e');
        }
        
        // Envoyer la requête avec progression
        final response = await request.send();
        
        print('[DEBUG UPLOAD] Réponse reçue - Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          print('[DEBUG UPLOAD] Réponse body: $responseBody');
          controller.add(1.0);
        } else {
          final responseBody = await response.stream.bytesToString();
          print('[ERREUR UPLOAD] Status ${response.statusCode}, Body: $responseBody');
          controller.addError('Upload failed: ${response.statusCode}');
        }
        
        await controller.close();
      } catch (e) {
        print('[ERREUR UPLOAD] $e');
        controller.addError(e);
        await controller.close();
      }
    }();
    
    return controller.stream;
  }

  // Nouvelle méthode pour uploader un dossier
  @override
  Stream<double> uploadFolder(List<File> files, String remotePath) {
    if (files.isEmpty) return Stream.value(0.0);
    
    final controller = StreamController<double>();
    
    () async {
      try {
        final uri = Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/upload-dossier');
        final request = http.MultipartRequest('POST', uri);
        
        // Ajouter le paramètre de chemin de destination
        request.fields['chemin_destination'] = remotePath;
        
        // Ajouter tous les fichiers
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileStream = http.ByteStream(file.openRead());
          final fileLength = await file.length();
          final multipartFile = http.MultipartFile(
            'files',
            fileStream,
            fileLength,
            filename: file.path.split('/').last,
          );
          request.files.add(multipartFile);
          
          // Émettre la progression
          controller.add((i + 1) / files.length);
        }
        
        final response = await request.send();
        
        if (response.statusCode == 200) {
          controller.add(1.0);
        } else {
          controller.addError('Upload failed: ${response.statusCode}');
        }
        
        await controller.close();
      } catch (e) {
        controller.addError(e);
        await controller.close();
      }
    }();
    
    return controller.stream;
  }

  Future<bool> completerAppairage(String host, Map<String, dynamic> donneesAppareil) async {
    final url = Uri.parse('http://$host:$_apiPort/api/v1/appairage/completer');
    print('[APPARIAGE] URL de l\'endpoint: $url');
    print('[APPARIAGE] Port API configuré: $_apiPort');
    print('[APPARIAGE] Données à envoyer: ${jsonEncode(donneesAppareil)}');
    
    try {
      print('[APPARIAGE] Envoi de la requête POST...');
      final reponse = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(donneesAppareil),
      );
      
      print('[APPARIAGE] Réponse reçue: Status=${reponse.statusCode}, Body=${reponse.body}');
      
      if (reponse.statusCode == 200) {
        print('[APPARIAGE] Appairage réussi côté serveur');
        return true;
      } else {
        print('[APPARIAGE] Erreur serveur: ${reponse.statusCode} - ${reponse.body}');
        return false;
      }
    } catch (e) {
      print('[APPARIAGE] Exception lors de l\'appairage: $e');
      print('[APPARIAGE] Type d\'erreur: ${e.runtimeType}');
      if (e is SocketException) {
        print('[APPARIAGE] Erreur de socket: ${e.message}');
      }
      return false;
    }
  }

  @override
  Future sendCommand(String command, Map<String, dynamic> params) async {
    try {
      final uri = Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/$command');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(params),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Commande échouée: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'exécution de la commande: $e');
    }
  }

  @override
  Future<bool> deleteRemote(String path) async {
    final uri = Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/supprimer')
        .replace(queryParameters: { 'chemin': path });
    final res = await http.delete(uri);
    return res.statusCode == 200;
  }

  @override
  Future<bool> renameRemote({required String fromPath, required String toPath}) async {
    final uri = Uri.parse('http://$_host:$_apiPort/api/v1/fichiers/renommer');
    final res = await http.post(
      uri,
      headers: { 'Content-Type': 'application/json' },
      body: jsonEncode({ 'source': fromPath, 'destination': toPath }),
    );
    return res.statusCode == 200;
  }
}
