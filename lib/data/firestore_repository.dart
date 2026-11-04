import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/shop.dart';
import 'demo_repository.dart';

/// Rows live in separate collections. A single revision serializes transactions
/// affecting inventory, reservations and money. No last-writer-wins snapshots.
class FirestoreRepository implements TransactionalShopRepository {
  final FirebaseFirestore firestore;
  final String storeId;
  FirestoreRepository(this.firestore, {this.storeId = 'bay-hai'});
  static const collections = [
    'products',
    'orders',
    'customers',
    'deliveries',
    'payroll',
    'audit',
    'notifications',
    'stockMoves',
  ];
  DocumentReference<Json> get meta =>
      firestore.doc('stores/$storeId/meta/state');
  CollectionReference<Json> rows(String name) =>
      firestore.collection('stores/$storeId/$name');
  static Map<String, Json> indexed(ShopData data, String name) {
    final result = <String, Json>{};
    for (final value in data.toJson()[name] as List) {
      final row = Json.from(value);
      // Legacy local demo rows have no IDs; assign only when importing explicitly.
      row['id'] ??= const Uuid().v4();
      result[row['id'] as String] = row;
    }
    return result;
  }

  Future<({ShopData data, int revision})> _read() async {
    // Queries are outside the transaction; the double-read detects intervening
    // commits. The transaction below compares the same revision before writes.
    for (var retry = 0; retry < 5; retry++) {
      final before = await meta.get(const GetOptions(source: Source.server));
      final revision = (before.data()?['revision'] as int?) ?? 0;
      final snapshots = await Future.wait(
        collections.map(
          (name) => rows(name).get(const GetOptions(source: Source.server)),
        ),
      );
      final after = await meta.get(const GetOptions(source: Source.server));
      if (revision != ((after.data()?['revision'] as int?) ?? 0)) continue;
      final json = <String, dynamic>{'schema': 1};
      for (var i = 0; i < collections.length; i++) {
        json[collections[i]] = snapshots[i].docs.map((doc) {
          final value = Json.from(doc.data()['value'] as Map);
          if (value['id'] != doc.id) {
            throw StateError('Sai mã chứng từ ${doc.reference.path}.');
          }
          return value;
        }).toList();
      }
      final data = ShopData.fromJson(json);
      for (final list in [
        data.orders,
        data.audit,
        data.stockMoves,
        data.notifications,
      ]) {
        list.sort((a, b) => '${b['at'] ?? ''}'.compareTo('${a['at'] ?? ''}'));
      }
      return (data: data, revision: revision);
    }
    throw StateError('Dữ liệu đang thay đổi liên tục. Vui lòng tải lại.');
  }

  @override
  Future<ShopData> load() async => (await _read()).data;
  @override
  Stream<ShopData> watch() => meta
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.isFromCache)
      .asyncMap((_) => load());
  @override
  Future<void> save(ShopData data) =>
      throw UnsupportedError('Dữ liệu thật chỉ được ghi qua giao dịch.');

  @override
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  ) async {
    actor.requireAccess();
    for (var retry = 0; retry < 5; retry++) {
      final snapshot = await _read();
      final next = snapshot.data.copy();
      final result = operation(next, actor);
      // Assign stable IDs before diffing and persisting new ledger entries.
      for (final list in [next.stockMoves, next.notifications]) {
        for (final row in list) {
          row['id'] ??= const Uuid().v4();
        }
      }
      final changes = <({String name, String id, Json value})>[];
      for (final name in collections) {
        final before = indexed(snapshot.data, name),
            after = indexed(next, name);
        if (before.keys.any((id) => !after.containsKey(id))) {
          throw StateError(
            'Không xóa chứng từ thật. Hãy ngừng sử dụng hoặc lập điều chỉnh.',
          );
        }
        for (final entry in after.entries) {
          if (jsonEncode(before[entry.key]) != jsonEncode(entry.value)) {
            if (utf8.encode(jsonEncode(entry.value)).length > 700000) {
              throw StateError(
                'Chứng từ/ảnh quá lớn. Hãy giảm ảnh hoặc cấu hình lưu ảnh Cloudinary.',
              );
            }
            changes.add((name: name, id: entry.key, value: entry.value));
          }
        }
      }
      if (changes.isEmpty) return (data: next, result: result);
      if (changes.length > 200) {
        throw StateError('Thao tác quá lớn; chia thành nhiều phiếu nhỏ.');
      }
      final mutationId = const Uuid().v4();
      // One immutable audit envelope per commit, required by Security Rules.
      final auditId = 'commit-$mutationId';
      final revision = snapshot.revision + 1;
      try {
        await firestore.runTransaction((tx) async {
          final current = await tx.get(meta);
          if (((current.data()?['revision'] as int?) ?? 0) !=
              snapshot.revision) {
            throw const RevisionConflict();
          }
          final envelope = <String, dynamic>{
            'revision': revision,
            'mutationId': mutationId,
            'updatedBy': actor.id,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(meta, {...envelope, 'auditId': auditId});
          tx.set(rows('audit').doc(auditId), {
            ...envelope,
            'value': {
              'id': auditId,
              'actor': actor.id,
              'action': 'Giao dịch đồng bộ',
              if (actor.displayName?.trim().isNotEmpty == true)
                'actorName': actor.displayName!.trim(),
              'target': mutationId,
              'at': DateTime.now().toUtc().toIso8601String(),
              'detail': changes.map((c) => '${c.name}/${c.id}').join(', '),
            },
          });
          for (final change in changes) {
            tx.set(rows(change.name).doc(change.id), {
              ...envelope,
              'value': change.value,
            });
            if (change.name == 'orders' &&
                !snapshot.data.orders.any((o) => o['id'] == change.id)) {
              final key = change.value['requestId'] as String;
              tx.set(rows('requests').doc(key), {
                ...envelope,
                'value': {'id': key, 'orderId': change.id},
              });
            }
          }
        });
        return (data: next, result: result);
      } on RevisionConflict {
        continue;
      } on FirebaseException catch (error) {
        // Rules may reject a stale revision before the native SDK reports an
        // ABORTED conflict. Only retry when a server read proves another commit
        // actually advanced it. Permission failures at the same revision stay errors.
        if ([
          'permission-denied',
          'aborted',
          'failed-precondition',
        ].contains(error.code)) {
          final current = await meta.get(
            const GetOptions(source: Source.server),
          );
          if (((current.data()?['revision'] as int?) ?? 0) !=
              snapshot.revision) {
            continue;
          }
        }
        rethrow;
      }
    }
    throw StateError(
      'Máy khác vừa cập nhật. Vui lòng thử lại, giỏ hàng vẫn được giữ.',
    );
  }
}

class RevisionConflict implements Exception {
  const RevisionConflict();
}
