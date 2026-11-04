import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/controllers/session_controller.dart';

const owner = Actor('admin', Role.owner);
const sales = Actor('nv', Role.sales);

class MemoryRepository implements ShopRepository {
  ShopData state = ShopData.sample();
  bool fail = false;
  @override
  Future<ShopData> load() async => state.copy();
  @override
  Future<void> save(ShopData data) async {
    if (fail) throw StateError('Disk full');
    state = data.copy();
  }
}

void main() {
  late ShopData d;
  setUp(() => d = ShopData.sample());
  test('login aliases normalize phone numbers and keep explicit emails', () {
    expect(loginEmail('ADMIN'), 'admin@accounts.bayhai.invalid');
    expect(loginEmail('+84901234567'), '0901234567@accounts.bayhai.invalid');
    expect(loginEmail('84901234567'), loginEmail('0901234567'));
    expect(loginEmail('Owner@Example.com'), 'owner@example.com');
    expect(() => loginEmail('../users/admin'), throwsArgumentError);
  });
  test('cancel held order releases reservation and records full deposit refund once', () {
    final initial = d.product('PR6060VD').stock;
    final o = d.checkout(
      requestId: 'cancel',
      lines: [const CartLine('PR6060VD', 144000)],
      customerId: 'KH001',
      paid: 1000000,
      ship: 0,
      hold: true,
      actor: owner,
    );
    d.cancelHeld(o['id'], 'Khách đổi kế hoạch, đã hoàn cọc', sales);
    d.cancelHeld(o['id'], 'Retry', sales);
    expect(d.product('PR6060VD').available, initial);
    expect(d.debt('KH001'), 0);
    expect(ShopData.netCollected(o), 0);
    expect(o['payments'], hasLength(1));
    expect(() => d.recordPayment(o['id'], 1, 'p2', sales), throwsStateError);
  });
  test('correction retains original payment and recomputes debt without extra revenue', () {
    final o = d.checkout(
      requestId: 'correct',
      lines: [const CartLine('PR6060VD', 144000)],
      customerId: 'KH001',
      paid: 1000000,
      ship: 0,
      hold: false,
      actor: owner,
    );
    d.correctPayment(
      o['id'],
      'correct-first',
      700000,
      'Ghi nhầm',
      'fix1',
      sales,
    );
    d.correctPayment(o['id'], 'correct-first', 700000, 'Retry', 'fix1', sales);
    expect(ShopData.collected(o), 700000);
    expect((o['payments'] as List).first['voided'], isTrue);
    expect(o['payments'], hasLength(2));
    expect(d.debt('KH001'), 2756000);
    expect(o['total'], 3456000);
  });
  test(
    'stale product editor cannot overwrite stock changed by another sale',
    () {
      final original = Product.fromJson(d.product('PR6060VD').toJson());
      // Clone nested lists just as a dialog does before editing.
      final expected = d.copy().product('PR6060VD');
      d.receive('PR6060VD', 14400, 100000, DateTime.now(), owner, 'new');
      expect(
        () => d.saveProduct(original, owner, expected: expected),
        throwsStateError,
      );
      expect(d.product('PR6060VD').stock, 1454400);
    },
  );
  Json checkout({
    String id = 'request1',
    int area = 144000,
    int paid = 1000000,
    bool hold = false,
    String reason = '',
  }) => d.checkout(
    requestId: id,
    lines: [CartLine('PR6060VD', area)],
    customerId: 'KH001',
    paid: paid,
    ship: 150000,
    hold: hold,
    actor: sales,
    negativeReason: reason,
  );

  test('carton conversion and VND rounding stay exact', () {
    expect(areaUnits(1.44), 14400);
    expect(lineMoney(144000, 240000), 3456000);
    expect(lineMoney(1, 235000), 24);
  });
  test('room estimate rounds cartons up and rejects invalid inputs', () {
    final r = RoomEstimate.calculate(5, 4, 5, 14400);
    expect(r.requiredArea, 210000);
    expect(r.cartons, 15);
    expect(r.purchasedArea, 216000);
    expect(() => RoomEstimate.calculate(0, 4, 5, 14400), throwsArgumentError);
    expect(
      () => RoomEstimate.calculate(double.nan, 4, 5, 14400),
      throwsArgumentError,
    );
    expect(() => RoomEstimate.calculate(5, 4, -1, 14400), throwsArgumentError);
  });
  test(
    'same checkout key remains idempotent after serializing and retrying',
    () {
      final first = checkout();
      final stock = d.product('PR6060VD').stock;
      d = d.copy();
      expect(checkout()['id'], first['id']);
      expect(d.orders, hasLength(1));
      expect(d.product('PR6060VD').stock, stock);
      expect(d.notifications, hasLength(1));
      expect(d.debt('KH001'), 2606000);
    },
  );
  test('aggregates duplicate lines before checking stock', () {
    final initial = d.product('PR6060VD').stock;
    expect(
      () => d.checkout(
        requestId: 'x',
        lines: [CartLine('PR6060VD', initial), const CartLine('PR6060VD', 1)],
        customerId: 'KH001',
        paid: 0,
        ship: 0,
        hold: false,
        actor: sales,
      ),
      throwsStateError,
    );
    expect(d.product('PR6060VD').stock, initial);
    expect(d.orders, isEmpty);
  });
  test('overpayment and unknown customer fail before inventory changes', () {
    final stock = d.product('PR6060VD').stock;
    expect(() => checkout(paid: 999999999), throwsArgumentError);
    expect(
      () => d.checkout(
        requestId: 'x',
        lines: [const CartLine('PR6060VD', 10000)],
        customerId: 'unknown',
        paid: 0,
        ship: 0,
        hold: false,
        actor: sales,
      ),
      throwsStateError,
    );
    expect(d.product('PR6060VD').stock, stock);
  });
  test('reservation reduces availability, not physical inventory; fulfilment keeps deposit', () {
    final initial = d.product('PR6060VD').stock;
    final o = checkout(hold: true);
    expect(d.product('PR6060VD').stock, initial);
    expect(d.product('PR6060VD').available, initial - 144000);
    d.fulfilHeld(o['id'], sales);
    d.fulfilHeld(o['id'], sales);
    expect(d.product('PR6060VD').stock, initial - 144000);
    expect(d.product('PR6060VD').reserved, 0);
    expect(ShopData.collected(o), 1000000);
    expect(o['status'], 'Đã bán');
  });
  test('negative stock requires reason and cannot be reserved', () {
    expect(() => checkout(area: 2000000), throwsStateError);
    expect(
      () => checkout(area: 2000000, reason: 'Chủ đã xác nhận', hold: true),
      throwsStateError,
    );
    checkout(area: 2000000, reason: 'Đã kiểm tra hàng về');
    expect(d.product('PR6060VD').stock, -560000);
    expect(d.orders.first['negativeReason'], isNotEmpty);
  });
  test('price and ratio edits never rewrite sale snapshots', () {
    final o = checkout();
    d.product('PR6060VD').price = 999000;
    d.product('PR6060VD').ratio = 12800;
    expect(o['lines'][0]['price'], 240000);
    expect(o['lines'][0]['ratio'], 14400);
    expect(o['total'], 3606000);
  });
  test(
    'non-contiguous imported order numbers never overwrite an existing order',
    () {
      checkout();
      d.orders.first['id'] = 'DH-2';
      final old = d.orders.first;
      final next = checkout(id: 'another-request');
      expect(next['id'], 'DH-3');
      expect(d.orders, hasLength(2));
      expect(d.orders.last, same(old));
    },
  );
  test('repayment is idempotent and does not create more revenue', () {
    final o = checkout();
    d.recordPayment(o['id'], 2606000, 'pay2', sales);
    d.recordPayment(o['id'], 2606000, 'pay2', sales);
    expect(d.debt('KH001'), 0);
    expect(o['total'], 3606000);
    expect(o['payments'], hasLength(2));
    expect(
      () => d.recordPayment(o['id'], 1, 'pay3', sales),
      throwsArgumentError,
    );
  });
  test('sales can finish trips and edit payroll; drivers cannot access', () {
    d.deliveries.add({'id': 'GH001', 'status': 'Đang giao'});
    d.finishDelivery('GH001', sales);
    d.finishDelivery('GH001', sales);
    expect(d.notifications, hasLength(1));
    d.setSalary('NV001', 9000000, 0, sales);
    expect(d.payroll.first['salary'], 9000000);
    expect(
      () => const Actor('tx', Role.driver).requireAccess(),
      throwsStateError,
    );
    d.setSalary('NV001', 9000000, 0, owner);
    expect(d.payroll.first['salary'], 9000000);
  });
  test('stock older than 60 days warns only when it still exists', () {
    final p = d.product('PR6060VD');
    p.lots.first['date'] = DateTime(2026, 1, 1).toIso8601String();
    expect(p.isOld(DateTime(2026, 3, 2)), isFalse);
    expect(p.isOld(DateTime(2026, 3, 3)), isTrue);
    p.lots.first['area'] = 0;
    expect(p.isOld(DateTime(2026, 3, 3)), isFalse);
  });
  test('failed persistence leaves current data and cart intact', () async {
    final repo = MemoryRepository()..fail = true;
    final c = ShopController(repo, d)..enterDemo(Role.owner);
    c.addCart(d.product('PR6060VD'), 144000);
    await expectLater(
      c.checkout(customerId: 'KH001', paid: 0, ship: 0),
      throwsStateError,
    );
    expect(c.data.orders, isEmpty);
    expect(c.data.product('PR6060VD').stock, 1440000);
    expect(c.cart, hasLength(1));
    expect(c.busy, isFalse);
  });
}
