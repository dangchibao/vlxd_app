import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

const owner = Actor('owner-uid', Role.owner);
const sales = Actor('sale-uid', Role.sales);

ShopData stocked() {
  final data = ShopData.empty();
  data.products.add(Product(
    id: 'GM4',
    code: 'GM4',
    name: 'Gạch 40x40',
    size: '40x40',
    supplier: 'Mỹ Đức',
    unitLabel: 'thùng',
    price: 95000,
    ratio: 0,
    minimum: 5000,
  ));
  data.receive(
      'GM4', areaUnits(4), 66500, DateTime(2026, 11, 1), owner, 'LO-OLD-001');
  return data;
}

void convertZero(ShopData data,
    {String reason = 'Nhập nhầm đơn vị', Actor actor = owner}) {
  data.correctReceivedProductUnit(
    productId: 'GM4',
    expectedProductJson: jsonEncode(data.product('GM4').toJson()),
    newUnit: 'm²',
    secondaryUnit: 'thùng',
    newRatio: areaUnits(2),
    newSalePrice: 10000,
    actualLotQuantities: {'LO-OLD-001': 0},
    reason: reason,
    actor: actor,
  );
}

void main() {
  test('Admin can switch unit when all lots empty; no phantom stock', () {
    final data = stocked();
    final lot = data.product('GM4').lots.single;
    lot['area'] = 0;
    data.stockMoves.add({
      'productId': 'GM4',
      'product': 'GM4',
      'type': 'Kiểm kê',
      'lot': 'LO-OLD-001',
      'area': -areaUnits(4),
    });
    final oldInbound = jsonEncode(data.stockMoves.first);
    convertZero(data);
    final p = data.product('GM4');
    expect(p.stock, 0);
    expect(p.unit, 'm²');
    expect(p.secondaryUnit, 'thùng');
    expect(p.ratio, areaUnits(2));
    expect(p.price, 10000);
    expect(p.minimum, 0);
    expect(p.lots.single['unitCorrection']['oldUnitCost'], 66500);
    expect(p.lots.single['unitCorrection']['oldInitialArea'], areaUnits(4));
    expect(p.lots.single['cost'], 0);
    expect(data.stockMoves.first['area'], 0);
    expect(data.stockMoves.first['type'], 'Đính chính đơn vị khi hết tồn');
    expect(jsonEncode(data.stockMoves[1]), oldInbound);
    expect(data.audit.first['action'], 'Đính chính đơn vị khi hết tồn');
  });

  test('Two-word reason is rejected; three words accepted', () {
    final data = stocked();
    data.product('GM4').lots.single['area'] = 0;
    expect(() => convertZero(data, reason: 'Nhập nhầm'), throwsArgumentError);
    convertZero(data, reason: 'Sai đơn vị');
    expect(data.product('GM4').unit, 'm²');
  });

  test('Sales role cannot change unit, even with zero stock', () {
    final data = stocked();
    data.product('GM4').lots.single['area'] = 0;
    expect(() => convertZero(data, actor: sales), throwsStateError);
    expect(data.product('GM4').unit, 'thùng');
  });

  test('Zero-stock correction rejected when historical order exists', () {
    final data = stocked();
    data.product('GM4').lots.single['area'] = 0;
    data.orders.add({'id': 'OD-1', 'lines': [{'productId': 'GM4'}]});
    expect(() => convertZero(data), throwsStateError);
  });

  test('Zero-stock correction rejected for other warehouse movements', () {
    final data = stocked();
    data.product('GM4').lots.single['area'] = 0;
    data.stockMoves.add({
      'productId': 'GM4',
      'product': 'GM4',
      'type': 'Xuất đơn giữ',
      'lot': 'LO-OLD-001',
      'area': -areaUnits(4),
    });
    expect(() => convertZero(data), throwsStateError);
  });

  test('Correction cannot be repeated without new reconciliation', () {
    final data = stocked();
    data.product('GM4').lots.single['area'] = 0;
    convertZero(data);
    final corrected = data.product('GM4');
    expect(corrected.lots.single['unitCorrection'], isNotNull);
    expect(() => data.correctReceivedProductUnit(
      productId: 'GM4',
      expectedProductJson: jsonEncode(corrected.toJson()),
      newUnit: 'cái',
      secondaryUnit: '',
      newRatio: 0,
      newSalePrice: 20000,
      actualLotQuantities: {'LO-OLD-001': 0},
      reason: 'Sai lại đơn vị',
      actor: owner,
    ), throwsStateError);
  });
}
