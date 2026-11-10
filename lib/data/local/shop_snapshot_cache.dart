import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/shop.dart';
import 'app_database.dart';

/// Server-confirmed data and a time-limited profile for the same Firebase UID.
class ShopSnapshotCache {
  ShopSnapshotCache(this.db);

  final AppDatabase db;
  Future<void>? _ready;
  static const maxAge = Duration(hours: 48);

  Future<void> _initialize() => _ready ??= db.customStatement('''
    CREATE TABLE IF NOT EXISTS offline_shop_cache (
      uid TEXT NOT NULL,
      kind TEXT NOT NULL,
      payload TEXT NOT NULL,
      saved_at INTEGER NOT NULL,
      PRIMARY KEY (uid, kind)
    )
  ''');

  Future<void> _save(String uid, String kind, Json value) async {
    await _initialize();
    await db.customStatement(
      '''
      INSERT INTO offline_shop_cache(uid, kind, payload, saved_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(uid, kind) DO UPDATE SET
        payload = excluded.payload, saved_at = excluded.saved_at
    ''',
      [uid, kind, jsonEncode(value), DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<({Json data, DateTime at})?> _read(String uid, String kind) async {
    await _initialize();
    final row = await db
        .customSelect(
          'SELECT payload, saved_at FROM offline_shop_cache WHERE uid = ? AND kind = ?',
          variables: [Variable.withString(uid), Variable.withString(kind)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(row.read<int>('saved_at'));
    final age = DateTime.now().difference(at);
    if (age.isNegative || age > maxAge) return null;
    return (data: jsonDecode(row.read<String>('payload')) as Json, at: at);
  }

  Future<void> save(String uid, ShopData data) =>
      _save(uid, 'shop', data.toJson());

  Future<({ShopData data, DateTime at})?> load(String uid) async {
    final row = await _read(uid, 'shop');
    return row == null ? null : (data: ShopData.fromJson(row.data), at: row.at);
  }

  Future<void> saveProfile(String uid, Json profile) =>
      _save(uid, 'profile', profile);

  Future<Json?> loadProfile(String uid) async =>
      (await _read(uid, 'profile'))?.data;

  Future<void> clear(String uid) async {
    await _initialize();
    await db.customStatement('DELETE FROM offline_shop_cache WHERE uid = ?', [
      uid,
    ]);
  }
}
