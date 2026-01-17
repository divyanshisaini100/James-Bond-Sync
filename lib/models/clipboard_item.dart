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
}
