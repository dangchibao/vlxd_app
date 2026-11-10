import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

const boss = Actor('admin', Role.owner), clerk = Actor('clerk', Role.sales);
Json sell(ShopData d, String id, {int paid = 0}) => d.checkout(
  requestId: id,
  lines: [const CartLine('PR6060VD', 14400)],
  customerId: 'KH001',
  paid: paid,
  ship: 0,
  hold: false,
  actor: clerk,
);

void main() {
  test('Book adjustment cannot recreate debt by lowering valid receipts', () {
    final d = ShopData.sample();
    sell(d, 'paid-order', paid: 345600);
    expect(
      () => d.adjustCustomerBook(
        'KH001',
        345600,
        295600,
        'Hạ đã thu',
        boss,
        expectedReceivable: 345600,
        expectedReceived: 345600,
      ),
      throwsStateError,
    );
    expect(d.debt('KH001'), 0);

    final customer = d.customers.firstWhere((c) => c['id'] == 'KH001');
    customer['receivedAdjustment'] = -50000;
    d.adjustCustomerBook(
      'KH001',
      345600,
      345600,
      'Khôi phục theo phiếu thu',
      boss,
      expectedReceivable: 345600,
      expectedReceived: 295600,
    );
    expect(d.debt('KH001'), 0);
  });

  test('A receipt is bounded by the order and the adjusted book', () {
    final d = ShopData.sample();
    final order = sell(d, 'adjusted-limit');
    d.adjustCustomerBook(
      'KH001',
      345600,
      50000,
      'Đã nhận ngoài sổ đơn',
      boss,
      expectedReceivable: 345600,
      expectedReceived: 0,
    );
    expect(d.collectible(order), 295600);
    d.recordPayment(order['id'], d.collectible(order), 'final-payment', clerk);
    expect(d.debt('KH001'), 0);
    expect(d.collectible(order), 0);
  });

  test('Opening debt book accepts target totals and audits without fake sales or inventory changes', () {
    final d = ShopData.sample();
    final stock = d.products.first.stock;
    d.adjustCustomerBook(
      'KH001',
      1000000,
      300000,
      'Nhập nợ cũ',
      boss,
      expectedReceivable: 0,
      expectedReceived: 0,
    );
    expect(d.customerBook('KH001'), (receivable: 1000000, received: 300000));
    expect(d.debt('KH001'), 700000);
    expect(d.orders, isEmpty);
    expect(d.products.first.stock, stock);
    expect(d.audit.first['action'], 'Điều chỉnh sổ công nợ');
    expect(ShopData.fromJson(d.toJson()).debt('KH001'), 700000);
  });
  test('Adjustments preserve invoices and normal subsequent sales/receipts remain additive', () {
    final d = ShopData.sample();
    final o = sell(d, 'one', paid: 100000);
    final original = jsonEncode(o);
    d.adjustCustomerBook(
      'KH001',
      500000,
      200000,
      'Đối chiếu sổ',
      boss,
      expectedReceivable: 345600,
      expectedReceived: 100000,
    );
    expect(jsonEncode(o), original);
    expect(d.debt('KH001'), 300000);
    sell(d, 'two', paid: 345600);
    expect(d.customerBook('KH001'), (receivable: 845600, received: 545600));
    d.recordPayment(o['id'], 100000, 'receipt', clerk);
    expect(d.debt('KH001'), 200000);
    expect(d.orders.length, 2);
  });
  test('Invalid and stale book changes fail before changing balances', () {
    final d = ShopData.sample();
    sell(d, 'one');
    final before = jsonEncode(d.toJson());
    for (final values in [(100, 200), (-1, 0), (0, -1)]) {
      expect(
        () => d.adjustCustomerBook(
          'KH001',
          values.$1,
          values.$2,
          'Lý do',
          boss,
          expectedReceivable: 345600,
          expectedReceived: 0,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => d.adjustCustomerBook(
        'KH001',
        400000,
        0,
        '',
        boss,
        expectedReceivable: 345600,
        expectedReceived: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => d.adjustCustomerBook(
        'KH001',
        400000,
        0,
        'Đối chiếu',
        boss,
        expectedReceivable: 0,
        expectedReceived: 0,
      ),
      throwsStateError,
    );
    expect(jsonEncode(d.toJson()), before);
  });
  test('Sales can adjust/archive; drivers, outstanding debt and held orders prevent archive', () {
    final d = ShopData.sample();
    expect(
      () => d.adjustCustomerBook(
        'KH001',
        100,
        0,
        'Không duyệt',
        const Actor('driver', Role.driver),
        expectedReceivable: 0,
        expectedReceived: 0,
      ),
      throwsStateError,
    );
    expect(
      () => d.archiveCustomer('KH001', const Actor('driver', Role.driver)),
      throwsStateError,
    );
    d.adjustCustomerBook(
      'KH001',
      0,
      0,
      'Đối chiếu',
      clerk,
      expectedReceivable: 0,
      expectedReceived: 0,
    );
    d.archiveCustomer('KH002', clerk);
    expect(
      d.customers.firstWhere((c) => c['id'] == 'KH002')['active'],
      isFalse,
    );
    sell(d, 'owe');
    expect(() => d.archiveCustomer('KH001', boss), throwsStateError);
    final held = ShopData.sample();
    held.checkout(
      requestId: 'hold',
      lines: [const CartLine('PR6060VD', 14400)],
      customerId: 'KH001',
      paid: 345600,
      ship: 0,
      hold: true,
      actor: boss,
    );
    expect(() => held.archiveCustomer('KH001', boss), throwsStateError);
  });
  test('Archive preserves paid invoices and blocks new sales to the hidden customer', () {
    final d = ShopData.sample();
    final o = sell(d, 'paid', paid: 345600);
    final before = jsonEncode(o);
    d.archiveCustomer('KH001', boss);
    expect(
      d.customers.firstWhere((x) => x['id'] == 'KH001')['active'],
      isFalse,
    );
    expect(jsonEncode(o), before);
    expect(() => sell(d, 'blocked'), throwsStateError);
    expect(d.orders.length, 1);
    d.correctPayment(
      o['id'],
      'paid-first',
      300000,
      'Đối chiếu lại lần thu',
      'fix-archived',
      boss,
    );
    expect(d.customers.firstWhere((x) => x['id'] == 'KH001')['active'], isTrue);
    expect(d.debt('KH001'), 45600);
  });
  test('Invoice receipts cannot overdraw an adjusted book balance', () {
    final d = ShopData.sample();
    final o = sell(d, 'owe');
    d.adjustCustomerBook(
      'KH001',
      100000,
      0,
      'Điều chỉnh giảm',
      boss,
      expectedReceivable: 345600,
      expectedReceived: 0,
    );
    expect(
      () => d.recordPayment(o['id'], 150000, 'too-much', clerk),
      throwsStateError,
    );
    expect(o['payments'], isEmpty);
    expect(d.debt('KH001'), 100000);
  });
}
