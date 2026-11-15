import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

void main() {
  Product product(String size, {String unit = ''}) => Product(
    id: 'P1',
    code: 'P1',
    name: 'Vật liệu',
    size: size,
    supplier: '',
    price: 10000,
    ratio: 0,
    unitLabel: unit,
  );

  test('legacy units survive loading without a unit field', () {
    expect(Product.fromJson(product('m³').toJson()).unit, 'm³');
    expect(Product.fromJson(product('60×60').toJson()).unit, 'm²');
  });

  test('custom unit is stored separately from size and survives reload', () {
    final original = product('60×60', unit: ' tấm ');
    final loaded = Product.fromJson(original.toJson());
    expect(loaded.unit, 'tấm');
    expect(loaded.size, '60×60');
    expect(loaded.toJson()['unit'], 'tấm');
  });
}
