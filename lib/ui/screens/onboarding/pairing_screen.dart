import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_cubit.dart';
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:hybrid_storage_app/core/services/crypto_service.dart';
import 'package:hybrid_storage_app/core/services/real_communication_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller.stop();
    }
    controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appairer un appareil')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) => _onDetect(capture),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text('Scannez le code affiché sur votre ordinateur.'),
            ),
          )
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    final Barcode? barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final String? raw = barcode?.rawValue;
    if (_isProcessing || raw == null) return;

    setState(() { _isProcessing = true; });
    await controller.stop();

    try {
      final decodedQr = jsonDecode(raw);
        final String nomHote = decodedQr['nom_hote'];
        final String clePubliqueServeurPem = decodedQr['cle_publique_pem'];
        // Nouvelles infos envoyées par le QR
        final String ip = decodedQr['ip'] ?? '127.0.0.1';
        final int apiPort = (decodedQr['api_port'] ?? 8001) as int;
        final int grpcPort = (decodedQr['grpc_port'] ?? 50051) as int;

        // 1. Générer la paire de clés pour ce mobile
        final cryptoService = getIt<CryptoService>();
        final paireDeClesMobile = cryptoService.genererPaireDeClesRSA();
        final clePubliqueMobilePem = cryptoService.encoderClePubliqueEnPem(paireDeClesMobile.clePublique);

        // 2. Préparer les données à envoyer au serveur
        final donneesAppareil = {
          "id_appareil": const Uuid().v4(), // Génère un ID unique pour ce mobile
          "nom_appareil": "Mon Appareil Mobile", // TODO: Rendre ce nom configurable
          "cle_publique_pem": clePubliqueMobilePem,
        };

        // 3. Envoyer les données au serveur pour compléter l'appairage
        final communicationService = getIt<CommunicationService>() as RealCommunicationService;
        communicationService.configureServer(host: ip, apiPort: apiPort, grpcPort: grpcPort);
        final success = await communicationService.completerAppairage(ip, donneesAppareil);

        if (success && mounted) {
          // 4. Vérifier que l'appareil est bien enregistré côté serveur
          await Future.delayed(const Duration(seconds: 2)); // Attendre un peu
          
          try {
            final response = await http.get(
              Uri.parse('http://$ip:$apiPort/api/v1/appareils'),
            );
            
            if (response.statusCode == 200) {
              final appareils = jsonDecode(response.body) as List;
              final appareilExiste = appareils.any((app) => app['id_appareil'] == donneesAppareil['id_appareil']);
              
              if (!appareilExiste) {
                throw Exception("L'appareil n'a pas été correctement enregistré côté serveur.");
              }
            } else {
              throw Exception("Impossible de vérifier l'enregistrement côté serveur.");
            }
          } catch (e) {
            print("Erreur lors de la vérification côté serveur: $e");
            throw Exception("Vérification côté serveur échouée: ${e.toString()}");
          }
          
          // 5. Sauvegarder les clés et marquer comme authentifié
          final clePriveeMobilePem = cryptoService.encoderClePriveeEnPem(paireDeClesMobile.clePrivee);
          
          // Sauvegarder le nom de l'ordinateur
          const storage = FlutterSecureStorage();
          await storage.write(key: 'computer_name', value: nomHote);
          
          context.read<AuthCubit>().devicePaired(
            idAppareil: donneesAppareil['id_appareil']!,
            clePriveeMobile: clePriveeMobilePem,
            clePubliqueServeur: clePubliqueServeurPem,
            serveurHost: ip,
            serveurApiPort: apiPort,
            serveurGrpcPort: grpcPort,
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          throw Exception("L'appairage a échoué côté serveur.");
        }

    } catch (e) {
      print("Erreur d'appairage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'appairage: ${e.toString()}")),
      );
      await controller.start();
      setState(() { _isProcessing = false; });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
