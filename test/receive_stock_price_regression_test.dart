import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/unit_rules.dart';

void main() {
  test('gia nhap kho khong duoc suy tu gia ban', () {
    final source = File('lib/ui/operations.dart').readAsStringSync();
    final start = source.indexOf('Future<void> receiveStock(');
    final end = source.indexOf('Future<void> inspectStock(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final receipt = source.substring(start, end);

    expect(receipt, isNot(contains('p.price')));
    expect(receipt, isNot(contains('initialBaseCost')));
    expect(receipt, isNot(contains("TextEditingController(text: '10')")));
    expect(receipt, contains('final qty = TextEditingController();'));
    expect(receipt, contains('final cost = TextEditingController();'));
    expect(receipt, contains('cost.text.trim().isEmpty'));
    expect(receipt, contains('Chưa nhập giá mua thực tế'));
    expect(receipt, contains('Giá vốn dự kiến'));
  });

  test('gia mua 126000/thung quy doi thanh 84000/m2', () {
    expect(
      baseUnitCostFromInput(
        enteredUnitCost: 126000,
        packRatio: 15000, // 1 thùng = 1.5 m²
        byPack: true,
      ),
      84000,
    );
    expect(
      baseQuantityFromInput(quantity: 10, packRatio: 15000, byPack: true),
      150000, // 15 m², lưu nội bộ 1/10000 m²
    );
    expect(
      baseUnitCostFromInput(
        enteredUnitCost: 90000,
        packRatio: 15000,
        byPack: false,
      ),
      90000,
    );
  });
}
