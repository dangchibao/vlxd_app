import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

void main() {
  const owner = Actor('owner-test', Role.owner);

  Product product({int stock = 0}) => Product(
        id: 'p-1', code: 'SP0001', name: 'Keo dán gạch', size: '25kg',
        supplier: '', price: 5000, ratio: 0,
        unitLabel: 'bao',
        lots: stock == 0 ? [] : [
          {'id':'lo-uuid', 'date':'2026-11-01T00:00:00.000',
           'area':stock, 'reserved':0, 'cost':2500, 'ratio':0},
        ],
      );

  test('Khong duoc doi don vi khi da co lo', () {
    final data = ShopData.empty();
    final before = product(stock:10000);
    data.products.add(before);
    final after = Product.fromJson(before.toJson())..unitLabel = 'cay';
    expect(() => data.saveProduct(after, owner, expected: before), throwsStateError);
    expect(data.product('p-1').unit, 'bao');
  });

  test('Co dinh so lo cu va lo moi khong trung', () {
    final data = ShopData.empty();
    data.products.add(product(stock:10000));
    data.assignMissingLotNumbers('p-1', owner);
    expect(data.product('p-1').lots.first['lotNumber'], 1);
    data.receive('p-1', 10000, 2500, DateTime(2026, 11, 5), owner, 'lo-2');
    expect(data.product('p-1').lots.last['lotNumber'], 2);
  });

  test('Tra toan bo don chi hoan ton mot lan', () {
    final data = ShopData.empty();
    data.products.add(product(stock:100000));
    final order = data.checkout(
      requestId:'test-return-1',lines:[const CartLine('p-1',10000)],
      customerId:'',paid:5000,ship:0,hold:false,actor:owner,
    );
    expect(data.product('p-1').stock, 90000);
    data.returnSoldOrder(order['id'] as String,
      'Khach tra du hang', owner, cashWasReturned:true);
    expect(data.product('p-1').stock, 100000);
    expect(order['status'], 'Đã trả hàng');
    expect(order['refund'], 5000);
    expect(() => data.returnSoldOrder(order['id'] as String,
      'Tra lan 2', owner, cashWasReturned:true), throwsStateError);
  });
}
