import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../models/clipboard_binary_payload.dart';

typedef ClipboardTextHandler = void Function(String text);
typedef ClipboardBinaryHandler = void Function(ClipboardBinaryPayload payload);

class ClipboardService {
  Timer? _pollTimer;
  String _lastText = '';
  String _suppressedText = '';
  String _lastBinarySignature = '';
  String _suppressedBinarySignature = '';

  void startMonitoring({
    required ClipboardTextHandler onText,
    required ClipboardBinaryHandler onBinary,
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      final systemClipboard = SystemClipboard.instance;
      if (systemClipboard == null) {
        await _readFallbackText(onText);
        return;
      }
      final reader = await systemClipboard.read();
      final imagePayload = await _readImage(reader);
      if (imagePayload != null) {
        _handleBinary(imagePayload, onBinary);
        return;
      }
      final filePayload = await _readFile(reader);
      if (filePayload != null) {
        _handleBinary(filePayload, onBinary);
        return;
      }
      final text = await reader.readValue(Formats.plainText) ?? '';
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
        onText(text);
      }
    });
  }

  Future<void> _readFallbackText(ClipboardTextHandler onText) async {
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
      onText(text);
    }
  }

  void _handleBinary(ClipboardBinaryPayload payload, ClipboardBinaryHandler onBinary) {
    final signature = _binarySignature(payload.bytes, payload.fileName);
    if (_suppressedBinarySignature.isNotEmpty &&
        signature == _suppressedBinarySignature) {
      _suppressedBinarySignature = '';
      _lastBinarySignature = signature;
      return;
    }
    if (signature == _lastBinarySignature) {
      return;
    }
    _lastBinarySignature = signature;
    onBinary(payload);
  }

  Future<void> setClipboardText(String text, {bool suppressNextRead = false}) async {
    if (suppressNextRead) {
      _suppressedText = text;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _lastText = text;
  }

  Future<void> setClipboardImage(Uint8List bytes,
      {String? mimeType, bool suppressNextRead = false}) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final format = _imageFormatForMime(mimeType);
    final item = DataWriterItem();
    item.add(format(bytes));
    await clipboard.write([item]);
    if (suppressNextRead) {
      _suppressedBinarySignature = _binarySignature(bytes, null);
    }
  }

  Future<ClipboardBinaryPayload?> _readImage(ClipboardReader reader) async {
    final imageFormats = <_ImageFormatCandidate>[
      _ImageFormatCandidate(Formats.png, 'image/png'),
      _ImageFormatCandidate(Formats.jpeg, 'image/jpeg'),
      _ImageFormatCandidate(Formats.gif, 'image/gif'),
      _ImageFormatCandidate(Formats.webp, 'image/webp'),
      _ImageFormatCandidate(Formats.bmp, 'image/bmp'),
      _ImageFormatCandidate(Formats.tiff, 'image/tiff'),
    ];
    for (final candidate in imageFormats) {
      final payload = await _readFileFormat(reader, candidate.format);
      if (payload != null) {
        return ClipboardBinaryPayload(
          bytes: payload.bytes,
          dataType: 'image',
          fileName: payload.fileName,
          mimeType: candidate.mimeType,
        );
      }
    }
    return null;
  }

  Future<ClipboardBinaryPayload?> _readFile(ClipboardReader reader) async {
    if (kIsWeb) {
      return null;
    }
    final uri = await reader.readValue(Formats.fileUri);
    if (uri == null) {
      return null;
    }
    final file = File(uri.toFilePath());
    final bytes = await file.readAsBytes();
    return ClipboardBinaryPayload(
      bytes: bytes,
      dataType: 'file',
      fileName: uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null,
      mimeType: null,
    );
  }

  Future<_FileReadResult?> _readFileFormat(
      ClipboardReader reader, FileFormat format) async {
    final completer = Completer<_FileReadResult?>();
    final progress = reader.getFile(format, (file) async {
      final bytes = await file.readAll();
      completer.complete(_FileReadResult(bytes: bytes, fileName: file.fileName));
    }, onError: (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    if (progress == null) {
      return null;
    }
    return completer.future.timeout(const Duration(seconds: 2), onTimeout: () => null);
  }

  String _binarySignature(Uint8List bytes, String? fileName) {
    final sample = bytes.length > 32 ? bytes.sublist(0, 32) : bytes;
    return '${bytes.length}:${fileName ?? ''}:${base64Encode(sample)}';
  }

  FileFormat _imageFormatForMime(String? mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return Formats.jpeg;
      case 'image/gif':
        return Formats.gif;
      case 'image/webp':
        return Formats.webp;
      case 'image/bmp':
        return Formats.bmp;
      case 'image/tiff':
        return Formats.tiff;
      default:
        return Formats.png;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
  }
}

class _FileReadResult {
  _FileReadResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

class _ImageFormatCandidate {
  _ImageFormatCandidate(this.format, this.mimeType);

  final FileFormat format;
  final String mimeType;
}
