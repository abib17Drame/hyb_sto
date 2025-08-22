import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/settings/settings_bloc.dart';
import 'package:hybrid_storage_app/bloc/settings/settings_event.dart';
import 'package:hybrid_storage_app/bloc/settings/settings_state.dart';
import 'package:hybrid_storage_app/ui/screens/settings/device_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsBloc()..add(LoadSettings()),
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              _buildSectionTitle(context, 'Gestion'),
              _buildNavigationTile(
                icon: Icons.devices,
                title: 'Appareils Appairés',
                subtitle: 'Gérer les ordinateurs connectés',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DeviceManagementScreen(),
                  ));
                },
              ),
              const Divider(),
              _buildSectionTitle(context, 'Règles de Transfert'),
              SwitchListTile(
                title: const Text('Transfert automatique'),
                subtitle: const Text('Transférer les fichiers quand l\'espace est faible'),
                value: state.isAutomaticTransferEnabled,
                onChanged: (bool value) {
                  context.read<SettingsBloc>().add(ToggleAutomaticTransfer(value));
                },
              ),
              _buildNavigationTile(
                icon: Icons.storage,
                title: 'Seuil de déclenchement',
                subtitle: '${state.storageThreshold}% d\'espace libre restant',
                onTap: () => _showThresholdDialog(context, state.storageThreshold),
              ),
              const Divider(),
              _buildSectionTitle(context, 'Sécurité'),
              _buildInfoTile(
                icon: Icons.enhanced_encryption,
                title: 'Chiffrement',
                subtitle: 'Activé (AES-256-GCM)',
              ),
              _buildNavigationTile(
                icon: Icons.password,
                title: 'Changer le mot de passe',
                subtitle: 'Modifier le mot de passe de chiffrement',
                onTap: () {
                  // TODO: Créer et naviguer vers ChangePasswordScreen
                },
              ),
              const Divider(),
              _buildSectionTitle(context, 'À propos'),
              _buildInfoTile(
                icon: Icons.info_outline,
                title: 'Version de l\'application',
                subtitle: '1.0.0 (Build 1)',
              ),
              _buildNavigationTile(
                icon: Icons.description,
                title: 'Licences open source',
                subtitle: 'Voir les dépendances du projet',
                onTap: () => showLicensePage(context: context),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, int currentThreshold) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        int selectedValue = currentThreshold;
        return AlertDialog(
          title: const Text('Changer le seuil'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Slider(
                value: selectedValue.toDouble(),
                min: 5,
                max: 50,
                divisions: 9,
                label: '$selectedValue%',
                onChanged: (double value) {
                  setState(() => selectedValue = value.toInt());
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Confirmer'),
              onPressed: () {
                context.read<SettingsBloc>().add(ChangeStorageThreshold(selectedValue));
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
