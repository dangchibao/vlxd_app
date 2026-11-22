import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/domain/unit_rules.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';

class _MemoryRepo implements ShopRepository {
  _MemoryRepo(this.state);
  ShopData state;
  @override
  Future<ShopData> load() async => state.copy();
  @override
  Future<void> save(ShopData data) async {
    state = data.copy();
  }
}

void main() {
  const owner = Actor('owner', Role.owner);
  tearDown(() => Get.reset());

  Product item() => Product(
    id: 'plug-id',
    code: 'PLUG5',
    name: 'Ổ cắm điện',
    size: '',
    unitLabel: 'cái',
    supplier: '',
    price: 10000,
    ratio: 50000, // 1 thùng = 5 cái
    minimum: 0,
    lots: [
      {
        'id': 'lot-a',
        'date': DateTime(2026, 11, 1).toIso8601String(),
        'area': 90000, // 9 cái
        'reserved': 0,
        'cost': 6000,
      },
    ],
  );

  test('m2 and m3 typed by keyboard are canonicalized', () {
    expect(canonicalProductUnit(' m2 '), 'm²');
    expect(canonicalProductUnit('M^3'), 'm³');
    expect(canonicalProductUnit('viên'), 'viên');
    expect(item().unit, 'cái');
    final metreCube = item()..unitLabel = 'm3';
    expect(metreCube.unit, 'm³');
    expect(metreCube.hasPackConversion, isFalse);
  });

  test('receive 1 thùng is 5 cái; price per carton is base cost', () {
    expect(
      baseQuantityFromInput(quantity: 1, packRatio: 50000, byPack: true),
      50000,
    );
    expect(
      baseQuantityFromInput(quantity: 4, packRatio: 50000, byPack: false),
      40000,
    );
    expect(
      baseUnitCostFromInput(
        enteredUnitCost: 50000,
        packRatio: 50000,
        byPack: true,
      ),
      10000,
    );
    expect(
      baseUnitCostFromInput(
        enteredUnitCost: 10000,
        packRatio: 50000,
        byPack: false,
      ),
      10000,
    );
    expect(
      () => baseQuantityFromInput(quantity: 0, packRatio: 50000, byPack: true),
      throwsArgumentError,
    );
    expect(
      () => baseUnitCostFromInput(
        enteredUnitCost: -1,
        packRatio: 50000,
        byPack: true,
      ),
      throwsArgumentError,
    );
  });

  test('1 thùng + 4 cái creates two invoice rows with one stock deduction', () {
    final data = ShopData.empty()..products.add(item());
    final order = data.checkout(
      requestId: 'units-two-lines',
      lines: const [
        CartLine('plug-id', 50000, saleUnit: 'thùng'),
        CartLine('plug-id', 40000, saleUnit: 'cái'),
      ],
      customerId: '',
      paid: 90000,
      ship: 0,
      hold: false,
      actor: owner,
    );
    final lines = (order['lines'] as List).cast<Map>();
    expect(lines, hasLength(2));
    expect(lines[0]['saleUnit'], 'thùng');
    expect(lines[1]['saleUnit'], 'cái');
    expect(lines[0]['amount'], 50000);
    expect(lines[1]['amount'], 40000);
    expect(order['total'], 90000);
    expect(data.product('plug-id').stock, 0);
    final allocated = lines
        .expand((l) => l['allocations'] as List)
        .fold<int>(0, (sum, a) => sum + (a['area'] as int));
    expect(allocated, 90000);
    data.returnSoldOrder(
      order['id'] as String,
      'Khách trả đủ hàng',
      owner,
      cashWasReturned: true,
    );
    expect(data.product('plug-id').stock, 90000);
  });

  test('same product checkout, held order then cancel releases 9 cái', () {
    final data = ShopData.empty()..products.add(item());
    data.customers.add({'id': 'C1', 'name': 'Nam', 'active': true});
    final order = data.checkout(
      requestId: 'units-held-lines',
      lines: const [
        CartLine('plug-id', 50000, saleUnit: 'thùng'),
        CartLine('plug-id', 40000, saleUnit: 'cái'),
      ],
      customerId: 'C1',
      paid: 0,
      ship: 0,
      hold: true,
      actor: owner,
    );
    expect(data.product('plug-id').reserved, 90000);
    data.cancelHeld(order['id'] as String, 'Khách đổi kế hoạch', owner);
    expect(data.product('plug-id').reserved, 0);
    expect(data.product('plug-id').stock, 90000);
  });

  test('cart keeps cartons and loose items apart, merges same unit', () {
    Get.testMode = true;
    final data = ShopData.empty()..products.add(item());
    final c = Get.put(ShopController(_MemoryRepo(data), data))
      ..enterDemo(Role.owner);
    final p = c.data.product('plug-id');
    c.addCart(p, 50000, saleUnit: 'thùng');
    c.addCart(p, 40000, saleUnit: 'cái');
    expect(c.cart, hasLength(2));
    expect(c.subtotal, 90000);
    expect(c.cart.first.saleUnit, 'thùng');
    expect(c.cart.last.saleUnit, 'cái');
    c.addCart(p, 10000, saleUnit: 'cái');
    expect(c.cart, hasLength(2));
    expect(c.cart.last.area, 50000);
    expect(c.subtotal, 100000);
  });

  test('offline checkout lines remain backward compatible', () {
    final oldLine = OfflineCheckoutLine.fromJson({
      'productId': 'plug-id',
      'area': 10000,
      'note': '',
      'quotedPrice': 10000,
      'quotedRatio': 50000,
    });
    expect(oldLine.saleUnit, '');
    const line = OfflineCheckoutLine(
      productId: 'plug-id',
      area: 50000,
      note: '',
      saleUnit: 'thùng',
      quotedPrice: 10000,
      quotedRatio: 50000,
    );
    expect(OfflineCheckoutLine.fromJson(line.toJson()).saleUnit, 'thùng');
  });
}
