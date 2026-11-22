import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

void main() {
  const owner = Actor('owner', Role.owner);

  ShopData createShop() {
    final data = ShopData.empty();
    data.products.add(
      Product(
        id: 'p1',
        code: 'SP01',
        name: 'Gach men',
        size: '60x60',
        supplier: '',
        price: 100000,
        ratio: 0,
        unitLabel: 'm2',
        images: ['base-image'],
        lots: [
          {
            'id': 'lot1',
            'date': '2026-11-01T00:00:00.000',
            'area': 20000,
            'reserved': 0,
            'cost': 50000,
            'ratio': 0,
          },
        ],
      ),
    );
    return data;
  }

  test('editing image after concurrent sale preserves latest stock', () {
    final data = createShop();
    final opened = data.copy().product('p1');
    final edit = data.copy().product('p1');
    edit.images.insert(0, 'new-image');
    data.product('p1').lots.first['area'] = 10000;
    data.saveProduct(edit, owner, expected: opened);
    final result = data.product('p1');
    expect(result.images.first, 'new-image');
    expect(result.stock, 10000);
    expect(result.lots.single['cost'], 50000);
  });

  test('a new incoming lot is not lost during product price edit', () {
    final data = createShop();
    final opened = data.copy().product('p1');
    final edit = data.copy().product('p1')..price = 123000;
    data.product('p1').lots.add({
      'id': 'lot2',
      'date': '2026-11-05T00:00:00.000',
      'area': 15000,
      'reserved': 0,
      'cost': 60000,
      'ratio': 0,
    });
    data.saveProduct(edit, owner, expected: opened);
    expect(data.product('p1').price, 123000);
    expect(data.product('p1').lots.length, 2);
    expect(data.product('p1').stock, 35000);
  });

  test('two devices editing the same product metadata still conflict', () {
    final data = createShop();
    final opened = data.copy().product('p1');
    final edit = data.copy().product('p1')..images.add('image-phone');
    data.product('p1').price = 222000;
    expect(
      () => data.saveProduct(edit, owner, expected: opened),
      throwsStateError,
    );
    expect(data.product('p1').price, 222000);
    expect(data.product('p1').images.length, 1);
  });

  test('editing lot date while stock changed is rejected', () {
    final data = createShop();
    final opened = data.copy().product('p1');
    final edit = data.copy().product('p1');
    edit.lots.first['date'] = '2026-11-03T00:00:00.000';
    data.product('p1').lots.first['area'] = 9000;
    expect(
      () => data.saveProduct(edit, owner, expected: opened),
      throwsStateError,
    );
    expect(data.product('p1').stock, 9000);
  });

  test('unit change still blocked if another device has added a lot', () {
    final data = createShop();
    data.product('p1').lots.clear();
    final opened = data.copy().product('p1');
    final edit = data.copy().product('p1')..unitLabel = 'bao';
    data.product('p1').lots.add({
      'id': 'newlot',
      'date': '2026-11-07T00:00:00.000',
      'area': 10000,
      'reserved': 0,
      'cost': 60000,
      'ratio': 0,
    });
    expect(
      () => data.saveProduct(edit, owner, expected: opened),
      throwsStateError,
    );
    expect(data.product('p1').unitLabel, 'm2');
  });
}
