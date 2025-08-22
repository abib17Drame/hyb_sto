import 'package:flutter/material.dart';
import 'package:hybrid_storage_app/ui/screens/onboarding/pairing_screen.dart';

// Écran de bienvenue, première étape du processus d'onboarding.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo ou icône de l'application
              const Icon(
                Icons.sync_alt,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),

              // Titre principal
              Text(
                'Bienvenue sur Hybrid Storage',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description concise de l'application
              Text(
                'Libérez de l\'espace sur votre téléphone en transférant vos fichiers de manière transparente et sécurisée vers votre ordinateur.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Bouton pour commencer le processus d'appairage
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  // Navigue vers l'écran d'appairage
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PairingScreen(),
                    ),
                  );
                },
                child: const Text('Commencer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
