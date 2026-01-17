import 'dart:typed_data';

class ClipboardBinaryPayload {
  ClipboardBinaryPayload({
    required this.bytes,
    required this.dataType,
    this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;
  final String dataType; // image | file
  final String? fileName;
  final String? mimeType;
}
