import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_bloc.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_event.dart';
import 'package:hybrid_storage_app/bloc/transfer/transfer_state.dart';
import 'package:hybrid_storage_app/core/models/file_info.dart' as app_models;
import 'package:hybrid_storage_app/core/di/service_locator.dart';
import 'package:hybrid_storage_app/core/services/communication_service.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'dart:io';

// Fonction utilitaire pour récupérer tous les fichiers d'un dossier
Future<List<File>> _getAllFilesFromDirectory(String directoryPath) async {
  final List<File> files = [];
  final directory = Directory(directoryPath);
  
  try {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }
  } catch (e) {
    print('Erreur lors de la lecture du dossier: $e');
  }
  
  return files;
}

// Écran des transferts, maintenant connecté au TransferBloc global.
class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<TransferBloc>(),
      child: const TransfersView(),
    );
  }
}

class TransfersView extends StatelessWidget {
  const TransfersView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transferts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En cours'),
              Tab(text: 'Terminés'),
              Tab(text: 'Échoués'),
            ],
          ),
        ),
        body: BlocBuilder<TransferBloc, TransferState>(
          builder: (context, state) {
            return Column(
              children: [
                // Message d'information pour les utilisateurs
                if (state.completedTransfers.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Choisissez le dossier de destination pour vos fichiers transférés',
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Liste des transferts
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTransferList(state.ongoingTransfers),
                      _buildTransferList(state.completedTransfers),
                      _buildTransferList(state.failedTransfers),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showUploadOptions(context),
          child: const Icon(Icons.upload),
          tooltip: 'Envoyer un fichier vers l\'ordinateur',
        ),
      ),
    );
  }

  Future<void> _selectAndUploadFile(BuildContext context) async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: picker.FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        
        // Créer un FileInfo pour le fichier sélectionné
        final fileInfo = app_models.FileInfo(
          name: fileName,
          path: file.path,
          sizeInBytes: await file.length(),
          type: app_models.FileType.file,
          modifiedAt: DateTime.now(),
          isLocal: true, // Le fichier est sur le smartphone
        );

        // Choisir le dossier de destination
        final destinationPath = await _showDestinationPicker(context);
        if (destinationPath != null) {
          // Démarrer l'upload
          context.read<TransferBloc>().add(StartUpload(fileInfo, destinationPath));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection du fichier: $e')),
      );
    }
  }

  Future<void> _selectAndUploadFolder(BuildContext context) async {
    try {
      final result = await picker.FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final directory = Directory(result);
        final files = await _getAllFilesFromDirectory(result);
        
        if (files.isNotEmpty) {
          // Créer un FileInfo pour le dossier sélectionné
          final fileInfo = app_models.FileInfo(
            name: directory.path.split('/').last,
            path: directory.path,
            sizeInBytes: 0, // Taille calculée à partir des fichiers
            type: app_models.FileType.directory,
            modifiedAt: DateTime.now(),
            isLocal: true, // Le dossier est sur le smartphone
          );

          // Choisir le dossier de destination
          final destinationPath = await _showDestinationPicker(context);
          if (destinationPath != null) {
            // Démarrer l'upload
            context.read<TransferBloc>().add(StartUpload(fileInfo, destinationPath));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le dossier sélectionné est vide')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection du dossier: $e')),
      );
    }
  }

  Future<String?> _showDestinationPicker(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => DestinationPickerDialog(),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (modalContext) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Envoyer un fichier'),
              onTap: () {
                Navigator.pop(modalContext);
                _selectAndUploadFile(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Envoyer un dossier'),
              onTap: () {
                Navigator.pop(modalContext);
                _selectAndUploadFolder(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransferList(List<Transfer> transfers) {
    if (transfers.isEmpty) {
      return const Center(child: Text('Aucun transfert dans cette catégorie.'));
    }
    return ListView.builder(
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _buildTransferListItem(transfer);
      },
    );
  }

  Widget _buildTransferListItem(Transfer transfer) {
    Icon leadingIcon;
    Widget trailing;

    if (transfer.status == TransferStatus.ongoing) {
      leadingIcon = const Icon(Icons.sync);
      trailing = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(value: transfer.progress),
      );
    } else if (transfer.status == TransferStatus.completed) {
      leadingIcon = Icon(
        Icons.check_circle,
        color: transfer.type == TransferType.download ? Colors.green : Colors.blue,
      );
      trailing = const Icon(Icons.done);
    } else { // failed
      leadingIcon = const Icon(Icons.error, color: Colors.red);
      trailing = IconButton(
        icon: const Icon(Icons.replay),
        onPressed: () {
          // TODO: Implémenter la logique pour relancer le transfert.
        },
      );
    }

    return ListTile(
      leading: leadingIcon,
      title: Text(transfer.file.name),
      subtitle: _buildSubtitle(transfer),
      trailing: trailing,
    );
  }

  Widget _buildSubtitle(Transfer transfer) {
    if (transfer.status == TransferStatus.ongoing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: transfer.progress),
          const SizedBox(height: 4),
          Text('${(transfer.progress * 100).toInt()}%'),
        ],
      );
    }
    if (transfer.status == TransferStatus.failed) {
      return Text(
        'Échoué: ${transfer.errorMessage}',
        style: const TextStyle(color: Colors.red),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (transfer.status == TransferStatus.completed && transfer.type == TransferType.upload) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(transfer.file.readableSize),
          const SizedBox(height: 2),
          Text(
            '✅ Envoyé vers ${transfer.remoteDestinationPath ?? '/'}',
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      );
    }
    return Text(transfer.file.readableSize);
  }
}

// Widget pour choisir le dossier de destination
class DestinationPickerDialog extends StatefulWidget {
  @override
  _DestinationPickerDialogState createState() => _DestinationPickerDialogState();
}

class _DestinationPickerDialogState extends State<DestinationPickerDialog> {
  String currentPath = '/';
  List<app_models.FileInfo> folders = [];
  bool isLoading = true;
  String? selectedPath;
  final TextEditingController _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      isLoading = true;
    });

    try {
      final communicationService = getIt<CommunicationService>();
      final files = await communicationService.listRemoteDirectory(currentPath);
      
      // Filtrer seulement les dossiers
      final directories = files.where((file) => file.type == app_models.FileType.directory).toList();
      
      setState(() {
        folders = directories;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement: $e')),
      );
    }
  }

  void _navigateToFolder(app_models.FileInfo folder) {
    setState(() {
      currentPath = folder.path;
      selectedPath = folder.path;
    });
    _loadFolders();
  }

  void _goBack() {
    if (currentPath == '/') return;
    
    final segments = currentPath.split('/').where((s) => s.isNotEmpty).toList();
    segments.removeLast();
    final newPath = '/' + segments.join('/');
    
    setState(() {
      currentPath = newPath;
      selectedPath = newPath;
    });
    _loadFolders();
  }

  Future<void> _createNewFolder() async {
    final folderName = _newFolderController.text.trim();
    if (folderName.isEmpty) return;

    try {
      final communicationService = getIt<CommunicationService>();
      await communicationService.sendCommand('creer-dossier', {'chemin': folderName});
      
      _newFolderController.clear();
      _loadFolders();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dossier "$folderName" créé')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir le dossier de destination'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Barre de navigation
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (currentPath != '/')
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goBack,
                      tooltip: 'Retour',
                    ),
                  Expanded(
                    child: Text(
                      'Chemin: $currentPath',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Créer un nouveau dossier
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderController,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau dossier',
                      hintText: 'Nom du dossier',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createNewFolder,
                  child: const Text('Créer'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Liste des dossiers
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final isSelected = selectedPath == folder.path;
                        
                        return GestureDetector(
                          onDoubleTap: () => _navigateToFolder(folder),
                          child: ListTile(
                            leading: const Icon(Icons.folder, color: Colors.amber),
                            title: Text(folder.name),
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                selectedPath = folder.path;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final destination = selectedPath ?? currentPath;
            Navigator.pop(context, destination);
          },
          child: const Text('Choisir ce dossier'),
        ),
      ],
    );
  }
}
