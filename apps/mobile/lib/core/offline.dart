import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

/// Bounded encrypted snapshots and durable mutation keys, partitioned by account.
class OfflineStore {
  OfflineStore(this.userId);
  final String userId;
  static const storage = FlutterSecureStorage();
  String get prefix => 'eatme.cache.$userId.';
  Future<void> cache(String path, Json value) async {
    final content = jsonEncode({
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'data': value,
    });
    if (content.length > 400000) return;
    await storage.write(key: '$prefix$path', value: content);
    final snapshots = (await storage.readAll()).entries.where((entry) => entry.key.startsWith('$prefix/') && entry.key != '${prefix}/profile' && entry.key != '${prefix}/catalog').toList();
    if (snapshots.length > 40) {
      snapshots.sort((a, b) => a.value.compareTo(b.value));
      for (final entry in snapshots.take(snapshots.length - 40)) {
        await storage.delete(key: entry.key);
      }
    }
  }

  Future<Json?> read(String path) async {
    final raw = await storage.read(key: '$prefix$path');
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map;
      return {
        ...Map<String, dynamic>.from(value['data'] as Map),
        '_offline': true,
        '_saved_at': value['saved_at'],
      };
    } on FormatException {
      return null;
    }
  }

  Future<List<Json>> pending() async {
    final raw = await storage.read(key: '${prefix}outbox');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> savePending(List<Json> value) =>
      storage.write(key: '${prefix}outbox', value: jsonEncode(value));
  Future<void> clearSnapshots() async {
    for (final key in (await storage.readAll()).keys.where(
      (key) => key.startsWith(prefix) && key != '${prefix}outbox',
    )) {
      await storage.delete(key: key);
    }
  }

  Future<void> clear() async {
    for (final key in (await storage.readAll()).keys.where(
      (key) => key.startsWith(prefix),
    )) {
      await storage.delete(key: key);
    }
  }
}
