class ClipboardItem {
  ClipboardItem({
    required this.id,
    required this.deviceId,
    required this.timestampMs,
    required this.dataType,
    required this.text,
    required this.hash,
  });

  final String id;
  final String deviceId;
  final int timestampMs;
  final String dataType;
  final String text;
  final String hash;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'timestampMs': timestampMs,
      'dataType': dataType,
      'text': text,
      'hash': hash,
    };
  }

  static ClipboardItem fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      timestampMs: json['timestampMs'] as int,
      dataType: json['dataType'] as String,
      text: json['text'] as String,
      hash: json['hash'] as String,
    );
  }
}
