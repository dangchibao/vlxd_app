import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

const owner = Actor('owner-uid', Role.owner);
const sales = Actor('sales-uid', Role.sales);

ShopData fresh() {
  final d = ShopData.empty();
  d.products.add(Product(
    id: 'P1', code: 'P1', name: 'Gach 40x40', size: '40x40',
    supplier: 'Test', price: 650000, ratio: 0,
    unitLabel: 'thùng', minimum: 50000,
  ));
  d.receive('P1', areaUnits(2), 600000, DateTime(2026, 11, 1), owner, 'lot-1');
  return d;
}

void correct(ShopData d, {Actor actor = owner, String? snapshot}) {
  d.correctReceivedProductUnit(
    productId: 'P1', expectedProductJson: snapshot ?? jsonEncode(d.product('P1').toJson()),
    newUnit: 'm²', secondaryUnit: 'thùng', newRatio: areaUnits(6),
    newSalePrice: 95000, actualLotQuantities: {'lot-1': areaUnits(12)},
    reason: 'Nhap nham don vi khi tao san pham', actor: actor,
  );
}

void main() {
  test('owner can correct untouched receipt, preserving cost and history', () {
    final d = fresh();
    final originalMove = jsonEncode(d.stockMoves.single);
    correct(d);
    final p = d.product('P1');
    expect(p.unit, 'm²');
    expect(p.secondaryUnit, 'thùng');
    expect(p.ratio, areaUnits(6));
    expect(p.stock, areaUnits(12));
    expect(p.price, 95000);
    expect(p.minimum, 0);
    expect(p.lots.single['cost'], 100000);
    expect(p.lots.single['initialArea'], areaUnits(12));
    expect(d.stockMoves, hasLength(2));
    expect(d.stockMoves.first['type'], 'Đính chính đơn vị nhập nhầm');
    expect(jsonEncode(d.stockMoves.last), originalMove);
    expect(d.audit.first['action'], 'Đính chính đơn vị nhập nhầm');
    expect(d.orders, isEmpty);
  });

  test('staff cannot correct stock units', () {
    final d = fresh();
    expect(() => correct(d, actor: sales), throwsStateError);
    expect(d.product('P1').unit, 'thùng');
  });

  test('a stale correction cannot override concurrent receipt', () {
    final d = fresh();
    final original = jsonEncode(d.product('P1').toJson());
    d.receive('P1', areaUnits(1), 100000, DateTime(2026, 11, 2), owner, 'lot-2');
    expect(() => correct(d, snapshot: original), throwsStateError);
    expect(d.product('P1').unit, 'thùng');
  });

  test('a product with orders cannot be corrected', () {
    final d = fresh();
    d.orders.add({'id': 'O1', 'lines': [{'productId': 'P1'}]});
    expect(() => correct(d), throwsStateError);
    expect(d.product('P1').unit, 'thùng');
  });

  test('a product with intervening stock moves cannot be corrected', () {
    final d = fresh();
    d.stockMoves.add({'productId': 'P1', 'product': 'P1',
      'type': 'Kiểm kê', 'lot': 'lot-1', 'area': 0});
    expect(() => correct(d), throwsStateError);
    expect(d.product('P1').unit, 'thùng');
  });

  test('a product with reserved stock cannot be corrected', () {
    final d = fresh();
    d.product('P1').lots.single['reserved'] = areaUnits(1);
    expect(() => correct(d), throwsStateError);
  });
}
