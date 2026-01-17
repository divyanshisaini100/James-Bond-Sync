import 'package:flutter/foundation.dart';

import '../models/clipboard_item.dart';
import 'storage_service.dart';

class HistoryStore extends ChangeNotifier {
  HistoryStore({required StorageService storageService}) : _storageService = storageService;

  final StorageService _storageService;
  final List<ClipboardItem> _items = <ClipboardItem>[];
  final Map<String, ClipboardItem> _byId = <String, ClipboardItem>{};

  List<ClipboardItem> get items => List.unmodifiable(_items);

  bool containsId(String id) => _byId.containsKey(id);

  Future<void> loadFromStorage() async {
    final items = await _storageService.loadHistory();
    _items
      ..clear()
      ..addAll(items);
    _byId
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
    notifyListeners();
  }

  void add(ClipboardItem item) {
    if (_byId.containsKey(item.id)) {
      return;
    }
    _items.insert(0, item);
    _byId[item.id] = item;
    _storageService.persistHistoryItem(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _byId.clear();
    _storageService.clearHistory();
    notifyListeners();
  }
}
