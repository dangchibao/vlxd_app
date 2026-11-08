import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/local/cart_draft_repository.dart';

void main() {
  late AppDatabase db;
  late CartDraftRepository drafts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    drafts = CartDraftRepository(db);
  });

  tearDown(() async => db.close());

  test('Lưu và khôi phục nháp từ SQLite theo tài khoản', () async {
    await drafts.save(
      actorId: 'nv1',
      requestId: 'req-1',
      lines: [
        {'productId': 'PR6060VD', 'area': 14400, 'note': 'Cần giao'},
      ],
    );
    final saved = await drafts.read('nv1');
    expect(saved!['requestId'], 'req-1');
    expect((saved['lines'] as List).single['area'], 14400);
    expect(await drafts.read('nv2'), isNull);
  });

  test('Giữ thông tin khách, phí giao, cọc và trạng thái giữ hàng', () async {
    await drafts.save(
      actorId: 'nv1',
      requestId: 'req-form',
      lines: [
        {'productId': 'PR6060VD', 'area': 10000, 'note': ''},
      ],
      customerId: 'KH001',
      shippingText: '25000',
      paidText: '300000',
      hold: true,
      negativeReason: 'Giao sau',
    );
    final raw = (await drafts.read('nv1'))!;
    expect(raw['customerId'], 'KH001');
    expect(raw['shippingText'], '25000');
    expect(raw['paidText'], '300000');
    expect(raw['hold'], isTrue);
    expect(raw['negativeReason'], 'Giao sau');
  });

  test('Ghi nháp mới không bị bản cũ ghi đè', () async {
    final first = drafts.save(
      actorId: 'nv1',
      requestId: 'req-1',
      lines: [
        {'productId': 'A', 'area': 10000, 'note': ''},
      ],
    );
    final second = drafts.save(
      actorId: 'nv1',
      requestId: 'req-2',
      lines: [
        {'productId': 'B', 'area': 20000, 'note': ''},
      ],
    );
    await Future.wait([first, second]);
    expect((await drafts.read('nv1'))!['requestId'], 'req-2');
  });

  test('Xóa nháp không ảnh hưởng tài khoản khác', () async {
    await drafts.save(actorId: 'nv1', requestId: 'a', lines: []);
    await drafts.save(actorId: 'nv2', requestId: 'b', lines: []);
    await drafts.delete('nv1');
    expect(await drafts.read('nv1'), isNull);
    expect((await drafts.read('nv2'))!['requestId'], 'b');
  });
}
