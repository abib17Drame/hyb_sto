import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_cubit.dart';
import 'package:hybrid_storage_app/bloc/auth/auth_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  String? _computerName;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadComputerName();
  }

  Future<void> _loadComputerName() async {
    final computerName = await _secureStorage.read(key: 'computer_name');
    setState(() {
      _computerName = computerName ?? 'Ordinateur inconnu';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appareils Appairés'),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.computer, color: Colors.green),
                  title: Text(_computerName ?? 'Chargement...'),
                  subtitle: const Text('Connecté'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _showUnpairDialog(context),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: Text('Aucun appareil appairé'),
            );
          }
        },
      ),
    );
  }

  void _showUnpairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dissocier l\'appareil'),
          content: const Text('Êtes-vous sûr de vouloir dissocier cet ordinateur ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text('Dissocier', style: TextStyle(color: Colors.red)),
              onPressed: () {
                context.read<AuthCubit>().unpairDevice();
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
