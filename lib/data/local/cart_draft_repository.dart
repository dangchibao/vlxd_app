import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Nháp giỏ hàng cục bộ; KHÔNG phải đơn đã chốt hay Outbox.
/// Mỗi tài khoản có tối đa một nháp trên thiết bị này.
class CartDraftRepository {
  CartDraftRepository(this.db);

  final AppDatabase db;
  Future<void>? _initialization;
  Future<void> _tail = Future<void>.value();

  Future<void> _initialize() => _initialization ??= db.customStatement('''
    CREATE TABLE IF NOT EXISTS local_cart_drafts (
      actor_id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  // Serialize all operations to avoid an older save overwriting a newer cart.
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) async {
      await _initialize();
      return action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> save({
    required String actorId,
    required String requestId,
    required List<Map<String, Object?>> lines,
    String customerId = '',
    String shippingText = '0',
    String paidText = '',
    bool hold = false,
    String negativeReason = '',
  }) {
    if (actorId.isEmpty || requestId.isEmpty) {
      throw ArgumentError('Nháp cần tài khoản và mã giao dịch hợp lệ.');
    }
    final json = jsonEncode({
      'version': 1,
      'actorId': actorId,
      'requestId': requestId,
      'lines': lines,
      'customerId': customerId,
      'shippingText': shippingText,
      'paidText': paidText,
      'hold': hold,
      'negativeReason': negativeReason,
    });
    return _serial(
      () => db.customStatement(
        '''INSERT INTO local_cart_drafts(actor_id, payload, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(actor_id) DO UPDATE SET
           payload = excluded.payload, updated_at = excluded.updated_at''',
        [actorId, json, DateTime.now().toUtc().toIso8601String()],
      ),
    );
  }

  Future<Map<String, dynamic>?> read(String actorId) => _serial(() async {
    final rows = await db
        .customSelect(
          'SELECT payload FROM local_cart_drafts WHERE actor_id = ?',
          variables: [Variable.withString(actorId)],
        )
        .get();
    if (rows.isEmpty) return null;
    final payload = jsonDecode(rows.single.read<String>('payload'));
    if (payload is! Map<String, dynamic> ||
        payload['version'] != 1 ||
        payload['actorId'] != actorId ||
        payload['lines'] is! List) {
      throw const FormatException('Dữ liệu giỏ nháp không hợp lệ.');
    }
    return payload;
  });

  Future<void> delete(String actorId) => _serial(
    () => db.customStatement(
      'DELETE FROM local_cart_drafts WHERE actor_id = ?',
      [actorId],
    ),
  );

  /// Dùng cho test / khi cần đợi mọi thao tác ghi nháp hoàn tất.
  Future<void> flush() => _tail;
}
