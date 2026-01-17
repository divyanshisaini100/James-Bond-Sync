import 'package:flutter/foundation.dart';

import '../models/clipboard_item.dart';

class HistoryStore extends ChangeNotifier {
  final List<ClipboardItem> _items = <ClipboardItem>[];
  final Map<String, ClipboardItem> _byId = <String, ClipboardItem>{};

  List<ClipboardItem> get items => List.unmodifiable(_items);

  bool containsId(String id) => _byId.containsKey(id);

  void add(ClipboardItem item) {
    if (_byId.containsKey(item.id)) {
      return;
    }
    _items.insert(0, item);
    _byId[item.id] = item;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _byId.clear();
    notifyListeners();
  }
}
