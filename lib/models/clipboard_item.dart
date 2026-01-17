class ClipboardItem {
  ClipboardItem({
    required this.id,
    required this.deviceId,
    required this.timestampMs,
    required this.dataType,
    required this.text,
    required this.hash,
    this.payloadBase64,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  final String id;
  final String deviceId;
  final int timestampMs;
  final String dataType;
  final String text;
  final String hash;
  final String? payloadBase64;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'timestampMs': timestampMs,
      'dataType': dataType,
      'text': text,
      'hash': hash,
      'payloadBase64': payloadBase64,
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }

  static ClipboardItem fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      timestampMs: json['timestampMs'] as int,
      dataType: json['dataType'] as String,
      text: json['text'] as String? ?? '',
      hash: json['hash'] as String,
      payloadBase64: json['payloadBase64'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
    );
  }
}
