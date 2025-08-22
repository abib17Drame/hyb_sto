import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

const backgroundTaskName = "hybridStorageCheck";

class BackgroundService {
  Timer? _timer;

  Future<void> initialize() async {
    // No-op for timer-based implementation
  }

  Future<void> schedulePeriodicCheck() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        const MethodChannel channel = MethodChannel('hybrid_storage_app/disk_space');
        final double? freeSpace = await channel.invokeMethod<double>('getFreeDiskSpaceGB');
        final double? totalSpace = await channel.invokeMethod<double>('getTotalDiskSpaceGB');
        if (freeSpace == null || totalSpace == null) return;
        final double freeSpacePercentage = (freeSpace / totalSpace) * 100;
        print("[Timer] Espace disque libre : ${freeSpacePercentage.toStringAsFixed(2)}%");
      } catch (e) {
        print("[Timer] Erreur vérification espace disque: $e");
      }
    });
    print("Tâche périodique (Timer) planifiée.");
  }

  Future<void> cancelAllTasks() async {
    _timer?.cancel();
    _timer = null;
    print("Tâches périodiques annulées.");
  }
}
