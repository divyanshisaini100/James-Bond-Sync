class PairedDevice {
  PairedDevice({
    required this.id,
    required this.name,
    this.isOnline = false,
    this.publicKey,
    this.sharedSecret,
  });

  final String id;
  final String name;
  bool isOnline;
  final String? publicKey;
  final String? sharedSecret;
}
