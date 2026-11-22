import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/domain/unit_rules.dart';

void main() {
  const owner = Actor('owner', Role.owner);

  Product build({
    String unit = 'cái',
    String alternate = '',
    int ratio = 0,
    int stock = 0,
  }) => Product(
    id: 'SKU-1',
    code: 'SKU1',
    name: 'Hàng thử',
    size: '',
    supplier: '',
    unitLabel: unit,
    secondaryUnitLabel: alternate,
    price: 10000,
    ratio: ratio,
    minimum: 0,
    lots: stock > 0
        ? [
            {
              'id': 'lot1',
              'date': DateTime(2026, 11, 1).toIso8601String(),
              'area': stock,
              'reserved': 0,
              'cost': 6000,
            },
          ]
        : [],
  );

  test('legacy thùng conversion and no-conversion products stay unchanged', () {
    final legacy = build(ratio: 50000);
    expect(legacy.secondaryUnit, 'thùng');
    expect(legacy.hasPackConversion, true);
    expect(legacy.factorForUnit('thùng'), 50000);
    expect(legacy.factorForUnit('cái'), productUnitScale);
    expect(legacy.toJson().containsKey('secondaryUnit'), false);
    final roundtrip = Product.fromJson(legacy.toJson());
    expect(roundtrip.secondaryUnit, 'thùng');
    expect(build(unit: 'bao').hasPackConversion, false);
    expect(build(unit: 'm3', ratio: 50000).hasPackConversion, false);
  });

  test('generic units kg/bao, bao/kg, m³/xe are reversible', () {
    final byBag = build(unit: 'kg', alternate: 'bao', ratio: 250000);
    expect(byBag.hasPackConversion, true);
    expect(byBag.packUnit, 'bao');
    expect(byBag.conversionFromUnit, 'bao');
    expect(byBag.conversionDisplayFactor, 25);
    expect(byBag.factorForUnit('bao'), 250000);
    expect(
      baseQuantityFromInput(quantity: 2, packRatio: byBag.ratio, byPack: true),
      500000,
    );
    expect(Product.fromJson(byBag.toJson()).secondaryUnit, 'bao');
    final byKg = build(unit: 'bao', alternate: 'kg', ratio: 400);
    expect(byKg.conversionFromUnit, 'bao');
    expect(byKg.conversionToUnit, 'kg');
    expect(byKg.conversionDisplayFactor, 25);
    expect(byKg.factorForUnit('kg'), 400); // 1 kg = 0.04 bao
    expect(
      baseQuantityFromInput(quantity: 25, packRatio: byKg.ratio, byPack: true),
      10000,
    );
    final cubic = build(unit: 'm3', alternate: 'xe', ratio: 30000);
    expect(cubic.unit, 'm³');
    expect(cubic.isSecondaryUnit('xe'), true);
    expect(cubic.factorForUnit('xe'), 30000);
  });

  test('one bao and two kg use two invoice rows, deduct same base stock', () {
    final p = build(unit: 'kg', alternate: 'bao', ratio: 250000, stock: 500000);
    final data = ShopData.empty()..products.add(p);
    final order = data.checkout(
      requestId: 'BAG25',
      lines: const [
        CartLine('SKU-1', 250000, saleUnit: 'bao'),
        CartLine('SKU-1', 20000, saleUnit: 'kg'),
      ],
      customerId: '',
      paid: 270000,
      ship: 0,
      hold: false,
      actor: owner,
    );
    final rows = (order['lines'] as List).cast<Map>();
    expect(rows.length, 2);
    expect(rows.first['saleUnit'], 'bao');
    expect(rows.first['ratio'], 250000);
    expect(rows.last['saleUnit'], 'kg');
    expect(order['total'], 270000);
    expect(data.product('SKU-1').stock, 230000);
    data.returnSoldOrder(
      order['id'] as String,
      'Khách trả đủ hàng',
      owner,
      cashWasReturned: true,
    );
    expect(data.product('SKU-1').stock, 500000);
  });

  test('history locks existing conversion but permits adding a new one', () {
    final old = build(unit: 'bao', stock: 20000);
    final data = ShopData.empty()..products.add(old);
    final edited = Product.fromJson(old.toJson())
      ..secondaryUnitLabel = 'kg'
      ..ratio = 400; // 1 kg = 0.04 bao
    data.saveProduct(edited, owner, expected: old);
    final saved = data.product('SKU-1');
    expect(saved.stock, 20000);
    expect(saved.secondaryUnit, 'kg');
    final attempted = Product.fromJson(saved.toJson())..ratio = 500;
    expect(
      () => data.saveProduct(attempted, owner, expected: saved),
      throwsStateError,
    );
    expect(data.product('SKU-1').ratio, 400);
    final unitChanged = Product.fromJson(saved.toJson())..unitLabel = 'kg';
    expect(
      () => data.saveProduct(unitChanged, owner, expected: saved),
      throwsStateError,
    );
  });

  test('rejects duplicate unit names and invalid ratios', () {
    final data = ShopData.empty();
    expect(
      () => data.saveProduct(
        build(unit: 'kg', alternate: 'kg', ratio: 50000),
        owner,
      ),
      throwsArgumentError,
    );
    expect(
      () => data.saveProduct(
        build(unit: 'kg', alternate: 'bao', ratio: -1),
        owner,
      ),
      throwsArgumentError,
    );
  });
}
