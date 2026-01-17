import 'package:flutter/foundation.dart';

import '../models/paired_device.dart';
import 'storage_service.dart';

class PairingManager extends ChangeNotifier {
  PairingManager({required StorageService storageService}) : _storageService = storageService;

  final StorageService _storageService;
  final List<PairedDevice> _devices = <PairedDevice>[];

  List<PairedDevice> get devices => List.unmodifiable(_devices);

  Future<void> loadFromStorage() async {
    final devices = await _storageService.loadPairedDevices();
    _devices
      ..clear()
      ..addAll(devices);
    notifyListeners();
  }

  void addDevice(PairedDevice device) {
    if (_devices.any((d) => d.id == device.id)) {
      return;
    }
    _devices.add(device);
    _storageService.persistPairedDevice(device);
    notifyListeners();
  }

  void removeDevice(String deviceId) {
    _devices.removeWhere((d) => d.id == deviceId);
    _storageService.removePairedDevice(deviceId);
    notifyListeners();
  }

  void updatePresence(String deviceId, bool isOnline) {
    for (final device in _devices) {
      if (device.id == deviceId) {
        device.isOnline = isOnline;
        notifyListeners();
        break;
      }
    }
  }
}
