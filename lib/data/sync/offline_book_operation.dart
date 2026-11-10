import 'dart:convert';

import '../../domain/shop.dart';
import '../local/app_database.dart';

/// Pending inventory receipt or debt payment. The immutable audit marker is
/// committed in the same Firestore transaction as the business mutation.
class OfflineBookOperation {
  static const receipt = 'receive-stock.v1';
  static const payment = 'collect-payment.v1';

  final String type, id, actorId, target;
  final int amount;
  final int? cost, ratio, expectedCollected;
  final String? unit;
  final DateTime? date;

  const OfflineBookOperation({
    required this.type,
    required this.id,
    required this.actorId,
    required this.target,
    required this.amount,
    this.cost,
    this.ratio,
    this.expectedCollected,
    this.unit,
    this.date,
  });

  static bool supports(String type) => type == receipt || type == payment;

  String get label => type == receipt ? 'Nhập kho' : 'Thu nợ';
  String get markerId => 'offline-$id';

  String encode() => jsonEncode({
    'id': id,
    'actorId': actorId,
    'target': target,
    'amount': amount,
    if (type == payment) 'expectedCollected': expectedCollected,
    if (type == receipt) ...{
      'cost': cost,
      'ratio': ratio,
      'unit': unit,
      'date': date?.toIso8601String(),
    },
  });

  factory OfflineBookOperation.decode(PendingOperation row) {
    final json = jsonDecode(row.payloadJson) as Json;
    if (!supports(row.operationType) ||
        json['id'] != row.id ||
        row.id.isEmpty ||
        row.id.contains('/')) {
      throw const FormatException('Mã giao dịch offline không hợp lệ.');
    }
    return OfflineBookOperation(
      type: row.operationType,
      id: row.id,
      actorId: json['actorId'] as String,
      target: json['target'] as String,
      amount: json['amount'] as int,
      cost: json['cost'] as int?,
      ratio: json['ratio'] as int?,
      expectedCollected: json['expectedCollected'] as int?,
      unit: json['unit'] as String?,
      date: json['date'] is String
          ? DateTime.parse(json['date'] as String)
          : null,
    );
  }

  void apply(ShopData data, Actor actor) {
    actor.requireAccess();
    if (actor.id != actorId || amount <= 0 || !supports(type)) {
      throw StateError(
        'Tài khoản hoặc số lượng giao dịch offline không hợp lệ.',
      );
    }
    final existing = data.audit
        .where((row) => row['id'] == markerId)
        .firstOrNull;
    if (existing != null) {
      if (existing['actor'] != actorId ||
          existing['operationType'] != type ||
          existing['operationPayload'] != encode()) {
        throw StateError('Mã giao dịch đã được dùng với nội dung khác.');
      }
      return;
    }

    if (type == receipt) {
      final product = data.product(target);
      if (!product.active ||
          product.ratio != ratio ||
          product.unit != unit ||
          cost == null ||
          date == null) {
        throw StateError(
          'Sản phẩm hoặc quy đổi đã đổi. Cần đối chiếu phiếu nhập.',
        );
      }
      data.receive(target, amount, cost!, date!, actor, 'LO-$id');
    } else {
      final order = data.orders.firstWhere((o) => o['id'] == target);
      if (ShopData.collected(order) != expectedCollected) {
        throw StateError(
          'Đơn đã có thay đổi số tiền thu. Cần đối chiếu khoản thu.',
        );
      }
      data.recordPayment(target, amount, id, actor);
    }
    data.audit.insert(0, {
      'id': markerId,
      'actor': actorId,
      'action': '$label offline đã đồng bộ',
      'target': target,
      'detail': 'Xác nhận giao dịch $id',
      'at': DateTime.now().toUtc().toIso8601String(),
      'operationType': type,
      'operationPayload': encode(),
    });
  }
}
