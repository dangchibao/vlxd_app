import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/local/cart_draft_repository.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

class _FakeLiveRepository implements TransactionalShopRepository {
  @override
  Future<ShopData> load() async => ShopData.sample();
  @override
  Future<void> save(ShopData data) async => throw UnsupportedError('no');
  @override
  Stream<ShopData> watch() => const Stream<ShopData>.empty();
  @override
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  ) async {
    final data = ShopData.sample();
    return (data: data, result: operation(data, actor));
  }
}

void main() {
  late AppDatabase db;
  late CartDraftRepository drafts;
  late OutboxRepository outbox;
  late ShopController c;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    drafts = CartDraftRepository(db);
    outbox = OutboxRepository(db);
    c = ShopController(_FakeLiveRepository(), ShopData.sample());
    c.attachCheckoutOutbox(outbox);
    c.attachCartDrafts(drafts);
    c.actor = const Actor('employee-001', Role.owner);
  });
  tearDown(() async {
    c.onClose();
    await db.close();
  });

  test('Thêm sản phẩm tự lưu nháp; khôi phục giữ mã request', () async {
    c.requestId = 'draft-1';
    c.addCart(c.data.product('PR6060VD'), 14400, note: 'Giao ngày mai');
    await drafts.flush();
    expect((await drafts.read('employee-001'))!['requestId'], 'draft-1');

    final restarted = ShopController(_FakeLiveRepository(), ShopData.sample());
    restarted.attachCheckoutOutbox(outbox);
    restarted.attachCartDrafts(drafts);
    restarted.actor = const Actor('employee-001', Role.owner);
    expect(await restarted.restoreLocalDraft(), isTrue);
    expect(restarted.requestId, 'draft-1');
    expect(restarted.cart.single.note, 'Giao ngày mai');
    restarted.onClose();
  });

  test('Khôi phục đầy đủ thông tin nháp thanh toán', () async {
    c.requestId = 'draft-full';
    c.addCart(c.data.product('PR6060VD'), 14400);
    c.updateDraftForm(
      customerId: 'KH001',
      shippingText: '15000',
      paidText: '50000',
      discountText: '25 000',
      hold: true,
      negativeReason: 'Chờ khách xác nhận',
    );
    await drafts.flush();
    final restarted = ShopController(_FakeLiveRepository(), ShopData.sample());
    restarted.attachCheckoutOutbox(outbox);
    restarted.attachCartDrafts(drafts);
    restarted.actor = const Actor('employee-001', Role.owner);
    expect(await restarted.restoreLocalDraft(), isTrue);
    expect(restarted.draftCustomerId, 'KH001');
    expect(restarted.draftShippingText, '15000');
    expect(restarted.draftPaidText, '50000');
    expect(restarted.draftDiscountText, '25 000');
    expect(restarted.draftHold, isTrue);
    expect(restarted.draftNegativeReason, 'Chờ khách xác nhận');
    restarted.onClose();
  });

  test('Không khôi phục thành giỏ mới khi request đã vào Outbox', () async {
    c.requestId = 'draft-outbox-1';
    c.addCart(c.data.product('PR6060VD'), 14400);
    await drafts.flush();
    await c.queueOfflineCheckout(
      outbox: outbox,
      customerId: 'KH001',
      paid: 0,
      ship: 0,
    );
    // Giả lập nháp cũ còn sót lại sau sự cố điện.
    await drafts.save(
      actorId: 'employee-001',
      requestId: 'draft-outbox-1',
      lines: [
        {'productId': 'PR6060VD', 'area': 14400, 'note': ''},
      ],
    );
    final restarted = ShopController(_FakeLiveRepository(), ShopData.sample());
    restarted.attachCheckoutOutbox(outbox);
    restarted.attachCartDrafts(drafts);
    restarted.actor = const Actor('employee-001', Role.owner);
    expect(await restarted.restoreLocalDraft(), isFalse);
    expect(restarted.cart, isEmpty);
    restarted.onClose();
  });
}
