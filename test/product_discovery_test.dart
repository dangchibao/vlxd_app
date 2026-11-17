import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/product_discovery.dart';
import 'package:vlxd_app/domain/shop.dart';

const actor = Actor('owner', Role.owner);

Product makeProduct({
  String id = 'P1',
  String code = 'KDG25',
  String name = 'Keo dán gạch',
  String size = '25kg',
  String unit = 'bao',
  String supplier = 'Prime',
  bool active = true,
  bool deleted = false,
}) => Product(
  id: id,
  code: code,
  name: name,
  size: size,
  unitLabel: unit,
  supplier: supplier,
  price: 100000,
  ratio: 0,
  active: active,
  deleted: deleted,
);

void main() {
  test('search ignores case, accents, repeated spaces and dimension glyph', () {
    final product = makeProduct(
      name: 'Gạch Prime vân mây',
      size: '60×60',
      code: 'PR60',
      unit: 'm²',
    );
    expect(ProductDiscovery.hasText(product, 'gach prime'), isTrue);
    expect(ProductDiscovery.hasText(product, '60x60'), isTrue);
    expect(ProductDiscovery.hasText(product, 'PR60'), isTrue);
    expect(ProductDiscovery.sameSpecification('60 x 60', '60×60'), isTrue);
    expect(ProductDiscovery.displaySpecification('60x60'), '60×60');
    expect(ProductDiscovery.sameSpecification('25 kg', '25kg'), isTrue);
    expect(ProductDiscovery.displaySpecification('25kg'), '25 kg');
  });

  test('duplicate candidates do not depend on the user-supplied SKU', () {
    final original = makeProduct();
    final candidates = ProductDiscovery.suggest(
      products: [original],
      name: 'keo dan gach',
      code: 'ABC999',
      specification: '25kg',
      unit: 'bao',
      supplier: 'Khác',
    );
    expect(candidates, hasLength(1));
    expect(candidates.single.product.id, original.id);
    expect(candidates.single.likelyDuplicate, isTrue);
  });

  test('typo is suggested, never automatically merged', () {
    final result = ProductDiscovery.suggest(
      products: [makeProduct()],
      name: 'Keo dáng gạch',
      code: 'SP02',
      specification: '25kg',
      unit: 'bao',
      supplier: '',
    );
    expect(result, hasLength(1));
    expect(result.single.exactName, isFalse);
    expect(result.single.likelyDuplicate, isFalse);
  });

  test('similar names with different sizes remain review candidates', () {
    final matches = ProductDiscovery.suggest(
      products: [makeProduct(size: '20kg')],
      name: 'Keo dán gạch',
      code: 'NEW',
      specification: '25kg',
      unit: 'bao',
      supplier: 'Prime',
    );
    expect(matches, hasLength(1));
    expect(matches.single.sameSpecification, isFalse);
    expect(matches.single.likelyDuplicate, isFalse);
  });

  test('hidden and discontinued products are still suggested', () {
    final matches = ProductDiscovery.suggest(
      products: [makeProduct(active: false, deleted: true)],
      name: 'keo dan gach',
      code: 'NEW',
      specification: '25kg',
      unit: 'bao',
      supplier: '',
    );
    expect(matches.single.product.deleted, isTrue);
  });

  test('keo dan gach is not mistakenly categorized as tile', () {
    expect(ProductDiscovery.suggestedCategory(makeProduct()), 'Keo và vữa');
    expect(ProductDiscovery.suggestedCategory(makeProduct(
      name: 'Gạch lát nền', size: '80x80', unit: 'm²',
    )), 'Gạch ốp lát');
    expect(ProductDiscovery.suggestedCategory(makeProduct(
      name: 'Hàng mới ABC', size: '25kg', unit: 'bao',
    )), 'Khác / chưa phân loại');
  });

  test('domain blocks duplicate same item using 60x60 and 60×60', () {
    final data = ShopData.empty();
    data.saveProduct(makeProduct(
      id: 'A', code: 'A', name: 'Gạch lát nền',
      size: '60×60', unit: 'm²',
    ), actor);
    expect(() => data.saveProduct(makeProduct(
      id: 'B', code: 'B', name: 'gach lat nen',
      size: '60x60', unit: 'm²',
    ), actor), throwsStateError);
    expect(data.products, hasLength(1));
  });

  test('reuse keeps the product and all lot IDs intact', () {
    final data = ShopData.empty();
    data.saveProduct(makeProduct(), actor);
    data.receive('P1', 100000, 75000, DateTime.now(), actor, 'UUID-OLD');
    final oldLotId = data.product('P1').lots.single['id'];
    final oldStock = data.product('P1').stock;
    data.receive('P1', 200000, 80000, DateTime.now(), actor, 'UUID-NEW');
    expect(data.products, hasLength(1));
    expect(data.product('P1').lots, hasLength(2));
    expect(data.product('P1').lots.first['id'], oldLotId);
    expect(data.product('P1').stock, oldStock + 200000);
    expect(data.stockMoves.where((m) => m['type'] == 'Nhập kho'), hasLength(2));
  });
}
