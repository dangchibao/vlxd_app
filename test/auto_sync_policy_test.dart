import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/sync/auto_sync_coordinator.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';

void main() {
  final example = OfflineCheckoutCommand(
    requestId: 'req-1',
    actorId: 'staff-1',
    customerId: 'cust-1',
    lines: const [
      OfflineCheckoutLine(
        productId: 'product-1',
        area: 10000,
        note: '',
        quotedPrice: 100000,
        quotedRatio: 10000,
      ),
    ],
    paid: 100000,
    ship: 0,
    hold: false,
    negativeReason: '',
    createdAt: DateTime.utc(2026, 11, 9),
  );

  bool allowed(
    OfflineCheckoutCommand command, {
    String id = 'req-1',
    String status = 'pending',
    int attempts = 0,
    String actor = 'staff-1',
  }) => AutoSyncCoordinator.canAttempt(
    command: command,
    operationId: id,
    status: status,
    attempts: attempts,
    actorId: actor,
  );

  test('never-sent valid checkout is eligible for server preflight', () {
    expect(allowed(example), isTrue);
  });
  test('attempted orders are never automatically retried', () {
    expect(allowed(example, attempts: 1), isFalse);
  });
  test('failed and syncing orders require review', () {
    expect(allowed(example, status: 'failed'), isFalse);
    expect(allowed(example, status: 'syncing'), isFalse);
  });
  test('identity and request ID must match', () {
    expect(allowed(example, actor: 'staff-2'), isFalse);
    expect(allowed(example, id: 'req-2'), isFalse);
  });
  test('negative-stock approval is never automatic', () {
    final negative = OfflineCheckoutCommand(
      requestId: example.requestId,
      actorId: example.actorId,
      customerId: example.customerId,
      lines: example.lines,
      paid: example.paid,
      ship: example.ship,
      hold: example.hold,
      negativeReason: 'Quản lý cần xác nhận bán âm',
      createdAt: example.createdAt,
    );
    expect(allowed(negative), isFalse);
  });
}
