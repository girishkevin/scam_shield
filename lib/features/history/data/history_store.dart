import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/history_entry.dart';
import 'history_crypto.dart';

class HistoryStore {
  HistoryStore({FlutterSecureStorage? storage, HistoryCrypto? crypto})
      : _storage = storage ?? const FlutterSecureStorage(),
        _crypto = crypto ?? HistoryCrypto();

  final FlutterSecureStorage _storage;
  final HistoryCrypto _crypto;

  static const _keyName = 'history_key_v1';
  static const maxEntries = 200;

  Future<Uint8List> _loadOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return base64Decode(existing);

    final key = HistoryCrypto.generateKey();
    await _storage.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/history.enc');
  }

  Future<List<HistoryEntry>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];

    try {
      final key = await _loadOrCreateKey();
      final json = await _crypto.decrypt(await file.readAsBytes(), key);
      final list = jsonDecode(json) as List;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Tampered, corrupted, or the key is gone: start fresh, never crash.
      await file.delete();
      return [];
    }
  }

  Future<void> save(List<HistoryEntry> entries) async {
    final key = await _loadOrCreateKey();
    final kept = entries.take(maxEntries).toList();
    final bytes = await _crypto.encrypt(
      jsonEncode(kept.map((e) => e.toJson()).toList()),
      key,
    );

    // Write to a temp file first, then swap, so a crash can't corrupt history.
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  /// Deletes the data and the key, so nothing can ever be recovered.
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    await _storage.delete(key: _keyName);
  }
}