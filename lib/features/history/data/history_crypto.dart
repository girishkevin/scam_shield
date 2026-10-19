import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM encryption. GCM gives confidentiality AND integrity:
/// if anyone changes the stored bytes, decryption fails.
class HistoryCrypto {
  HistoryCrypto() : _algo = AesGcm.with256bits();

  final AesGcm _algo;

  /// A new random 256-bit key from the OS secure random generator.
  static Uint8List generateKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  }

  /// Output layout: nonce (12 bytes) + ciphertext + auth tag (16 bytes).
  /// A fresh random nonce is generated for every call.
  Future<Uint8List> encrypt(String plainText, List<int> key) async {
    final box = await _algo.encrypt(
      utf8.encode(plainText),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(box.concatenation());
  }

  /// Throws if the key is wrong or the data was changed.
  Future<String> decrypt(List<int> data, List<int> key) async {
    final box = SecretBox.fromConcatenation(
      data,
      nonceLength: _algo.nonceLength,
      macLength: _algo.macAlgorithm.macLength,
    );
    final clear = await _algo.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(clear);
  }
}