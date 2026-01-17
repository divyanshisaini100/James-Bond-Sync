import 'package:flutter/foundation.dart';

import '../models/paired_device.dart';

class PairingManager extends ChangeNotifier {
  final List<PairedDevice> _devices = <PairedDevice>[];

  List<PairedDevice> get devices => List.unmodifiable(_devices);

  void addDevice(PairedDevice device) {
    if (_devices.any((d) => d.id == device.id)) {
      return;
    }
    _devices.add(device);
    notifyListeners();
  }

  void removeDevice(String deviceId) {
    _devices.removeWhere((d) => d.id == deviceId);
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
