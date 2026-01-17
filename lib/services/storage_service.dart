import 'package:hive_flutter/hive_flutter.dart';

import '../models/clipboard_item.dart';
import '../models/paired_device.dart';

class StorageService {
  static const String _historyBox = 'clipboard_history';
  static const String _pairedDevicesBox = 'paired_devices';
  static const String _offlineQueueBox = 'offline_queue';
  static const String _identityBox = 'identity';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Hive.initFlutter();
    await Hive.openBox<Map>(_historyBox);
    await Hive.openBox<Map>(_pairedDevicesBox);
    await Hive.openBox<Map>(_offlineQueueBox);
    await Hive.openBox<Map>(_identityBox);
    _initialized = true;
  }

  Future<List<ClipboardItem>> loadHistory() async {
    final box = Hive.box<Map>(_historyBox);
    final items = box.values
        .map((value) => ClipboardItem.fromJson(Map<String, dynamic>.from(value)))
        .toList();
    items.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return items;
  }

  Future<void> persistHistoryItem(ClipboardItem item) async {
    final box = Hive.box<Map>(_historyBox);
    await box.put(item.id, item.toJson());
  }

  Future<void> clearHistory() async {
    final box = Hive.box<Map>(_historyBox);
    await box.clear();
  }

  Future<List<PairedDevice>> loadPairedDevices() async {
    final box = Hive.box<Map>(_pairedDevicesBox);
    return box.values
        .map((value) {
          final json = Map<String, dynamic>.from(value);
          return PairedDevice(
            id: json['id'] as String,
            name: json['name'] as String,
            isOnline: false,
            publicKey: json['publicKey'] as String?,
            sharedSecret: json['sharedSecret'] as String?,
          );
        })
        .toList();
  }

  Future<void> persistPairedDevice(PairedDevice device) async {
    final box = Hive.box<Map>(_pairedDevicesBox);
    await box.put(device.id, {
      'id': device.id,
      'name': device.name,
      'publicKey': device.publicKey,
      'sharedSecret': device.sharedSecret,
    });
  }

  Future<void> removePairedDevice(String deviceId) async {
    final box = Hive.box<Map>(_pairedDevicesBox);
    await box.delete(deviceId);
  }

  Future<Map<String, List<ClipboardItem>>> loadOfflineQueue() async {
    final box = Hive.box<Map>(_offlineQueueBox);
    final Map<String, List<ClipboardItem>> result = {};
    for (final entry in box.toMap().entries) {
      final deviceId = entry.key as String;
      final list = entry.value['items'] as List<dynamic>? ?? <dynamic>[];
      result[deviceId] = list
          .map((e) => ClipboardItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return result;
  }

  Future<void> persistQueue(String deviceId, List<ClipboardItem> items) async {
    final box = Hive.box<Map>(_offlineQueueBox);
    await box.put(deviceId, {
      'items': items.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> removeQueue(String deviceId) async {
    final box = Hive.box<Map>(_offlineQueueBox);
    await box.delete(deviceId);
  }

  Future<void> clearAll() async {
    await Hive.box<Map>(_historyBox).clear();
    await Hive.box<Map>(_pairedDevicesBox).clear();
    await Hive.box<Map>(_offlineQueueBox).clear();
    await Hive.box<Map>(_identityBox).clear();
  }

  Map<String, dynamic>? loadIdentity() {
    final box = Hive.box<Map>(_identityBox);
    final data = box.get('device');
    if (data == null) {
      return null;
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> persistIdentity(Map<String, dynamic> identity) async {
    final box = Hive.box<Map>(_identityBox);
    await box.put('device', identity);
  }
}
