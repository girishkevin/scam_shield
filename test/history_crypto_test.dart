import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_shield/features/history/data/history_crypto.dart';

void main() {
  final crypto = HistoryCrypto();

  test('generated keys are 32 bytes and different each time', () {
    final a = HistoryCrypto.generateKey();
    final b = HistoryCrypto.generateKey();
    expect(a.length, 32);
    expect(a, isNot(equals(b)));
  });

  test('encrypt then decrypt returns the original text', () async {
    final key = HistoryCrypto.generateKey();
    final data = await crypto.encrypt('your SBI account will be blocked', key);
    expect(await crypto.decrypt(data, key), 'your SBI account will be blocked');
  });

  test('ciphertext does not contain the plain text', () async {
    final key = HistoryCrypto.generateKey();
    final data = await crypto.encrypt('secret-message-123', key);
    expect(String.fromCharCodes(data).contains('secret-message-123'), isFalse);
  });

  test('same text encrypts differently each time (random nonce)', () async {
    final key = HistoryCrypto.generateKey();
    final a = await crypto.encrypt('hello', key);
    final b = await crypto.encrypt('hello', key);
    expect(a, isNot(equals(b)));
  });

  test('wrong key fails to decrypt', () async {
    final data = await crypto.encrypt('hello', HistoryCrypto.generateKey());
    expect(
          () => crypto.decrypt(data, HistoryCrypto.generateKey()),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('tampered data is detected', () async {
    final key = HistoryCrypto.generateKey();
    final data = await crypto.encrypt('hello', key);
    data[data.length - 1] ^= 0xFF; // flip bits in the auth tag
    expect(
          () => crypto.decrypt(data, key),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}