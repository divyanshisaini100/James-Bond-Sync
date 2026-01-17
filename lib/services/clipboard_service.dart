import 'dart:async';

import 'package:flutter/services.dart';

typedef ClipboardChangeHandler = void Function(String text);

class ClipboardService {
  Timer? _pollTimer;
  String _lastText = '';
  String _suppressedText = '';

  void startMonitoring(ClipboardChangeHandler onChange) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      if (text.isEmpty) {
        return;
      }
      if (_suppressedText.isNotEmpty && text == _suppressedText) {
        _suppressedText = '';
        _lastText = text;
        return;
      }
      if (text != _lastText) {
        _lastText = text;
        onChange(text);
      }
    });
  }

  Future<void> setClipboardText(String text, {bool suppressNextRead = false}) async {
    if (suppressNextRead) {
      _suppressedText = text;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _lastText = text;
  }

  void dispose() {
    _pollTimer?.cancel();
  }
}
