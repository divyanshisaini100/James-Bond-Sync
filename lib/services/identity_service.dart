import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'storage_service.dart';

class IdentityService {
  IdentityService({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;
  final SimpleKeyPairType _keyType = X25519();
  SimpleKeyPair? _keyPair;
  SimplePublicKey? _publicKey;

  Future<void> init() async {
    final stored = _storageService.loadIdentity();
    if (stored != null) {
      final privateKeyBytes = base64Decode(stored['privateKey'] as String);
      final publicKeyBytes = base64Decode(stored['publicKey'] as String);
      _keyPair = SimpleKeyPairData(privateKeyBytes, type: _keyType);
      _publicKey = SimplePublicKey(publicKeyBytes, type: _keyType);
      return;
    }
    _keyPair = await _keyType.newKeyPair();
    final publicKey = await _keyPair!.extractPublicKey();
    _publicKey = publicKey;
    await _storageService.persistIdentity({
      'privateKey': base64Encode(await _keyPair!.extractPrivateKeyBytes()),
      'publicKey': base64Encode(publicKey.bytes),
    });
  }

  Future<void> rotateKeys() async {
    _keyPair = await _keyType.newKeyPair();
    final publicKey = await _keyPair!.extractPublicKey();
    _publicKey = publicKey;
    await _storageService.persistIdentity({
      'privateKey': base64Encode(await _keyPair!.extractPrivateKeyBytes()),
      'publicKey': base64Encode(publicKey.bytes),
    });
  }

  String get publicKeyBase64 => base64Encode(_publicKey!.bytes);

  Future<String> deriveSharedSecretBase64(String remotePublicKeyBase64) async {
    final remotePublicKey = SimplePublicKey(base64Decode(remotePublicKeyBase64), type: _keyType);
    final sharedSecret = await X25519().sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: remotePublicKey,
    );
    final bytes = await sharedSecret.extractBytes();
    return base64Encode(bytes);
  }

  Future<String> hashPairCode(String code) async {
    final hash = await Sha256().hash(code.codeUnits);
    return base64Encode(hash.bytes);
  }
}
