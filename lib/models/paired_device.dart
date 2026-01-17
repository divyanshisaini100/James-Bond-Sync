class PairedDevice {
  PairedDevice({
    required this.id,
    required this.name,
    this.isOnline = false,
  });

  final String id;
  final String name;
  bool isOnline;
}
