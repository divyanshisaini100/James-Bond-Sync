import 'package:flutter/foundation.dart';

class MonitoringEntry {
  MonitoringEntry(this.message) : timestamp = DateTime.now();

  final String message;
  final DateTime timestamp;
}

class MonitoringService extends ChangeNotifier {
  final List<MonitoringEntry> _entries = <MonitoringEntry>[];

  List<MonitoringEntry> get entries => List.unmodifiable(_entries);

  void log(String message) {
    _entries.insert(0, MonitoringEntry(message));
    if (_entries.length > 100) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
