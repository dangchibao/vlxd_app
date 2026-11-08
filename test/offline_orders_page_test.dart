import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/data/sync/outbox_reconciler.dart';
import 'package:vlxd_app/data/sync/firebase_request_verifier.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/offline_orders.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late ShopController shop;

  setUp(() {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    Get.put<OutboxRepository>(outbox);
    shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()));
    shop.actor = const Actor('employee-001', Role.owner);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  Future<void> addOrder({
    required String id,
    String actorId = 'employee-001',
    String customerId = 'KH001',
  }) async {
    await outbox.enqueueCheckout(
      OfflineCheckoutCommand(
        requestId: id,
        actorId: actorId,
        customerId: customerId,
        lines: const [
          OfflineCheckoutLine(
            productId: 'PR6060VD',
            area: 14400,
            note: 'Giao buổi sáng',
            quotedPrice: 180000,
            quotedRatio: 14400,
          ),
        ],
        paid: 100000,
        ship: 20000,
        hold: false,
        negativeReason: '',
        createdAt: DateTime.utc(2026, 11, 8),
      ),
    );
  }

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GetMaterialApp(home: OfflineOrdersPage()));
    await tester.pumpAndSettle();
  }

  // Drift schedules a zero-delay timer when its watched query is cancelled.
  // Unmount the StreamBuilder and flush that timer inside fakeAsync before
  // Flutter's test binding checks for pending timers.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('Hiển thị pending và xem chi tiết từ SQLite', (tester) async {
    await addOrder(id: 'offline-page-001');
    await openPage(tester);

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-001')),
      findsOneWidget,
    );
    expect(find.textContaining('Chờ đồng bộ'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('offline-order-offline-page-001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn offline'), findsOneWidget);
    expect(
      find.text('Khách hàng: Anh Minh • Công trình Gò Dầu'),
      findsOneWidget,
    );
    expect(find.text('Mã khách hàng: KH001'), findsOneWidget);
    expect(
      find.text('Nhân viên: Chưa có tên nhân viên đã lưu'),
      findsOneWidget,
    );
    expect(find.text('Tiền đã thu: 100.000 đ'), findsOneWidget);
    expect(find.text('Phí giao hàng: 20.000 đ'), findsOneWidget);
    expect(find.textContaining('Mã sản phẩm: PR6060VD'), findsOneWidget);
    expect(find.textContaining('Giao buổi sáng'), findsOneWidget);
    expect((await outbox.getById('offline-page-001'))!.status, 'pending');
    expect(tester.takeException(), isNull);
    await closePage(tester);
  });

  testWidgets('Hiển thị failed nhưng không tự gửi hay đổi trạng thái', (
    tester,
  ) async {
    await addOrder(id: 'offline-page-failed');
    await outbox.markFailed('offline-page-failed', 'Cần đối chiếu server');
    final before = (await outbox.getById('offline-page-failed'))!;

    await openPage(tester);
    expect(find.textContaining('Cần xác minh'), findsWidgets);
    await tester.tap(find.byTooltip('Làm mới danh sách'));
    await tester.pumpAndSettle();

    final after = (await outbox.getById('offline-page-failed'))!;
    expect(after.status, 'failed');
    expect(after.attempts, before.attempts);
    expect(after.lastError, before.lastError);
    expect(tester.takeException(), isNull);
    await closePage(tester);
  });

  testWidgets('Đơn lỗi hiện hướng dẫn xác minh và sao chép request ID', (
    tester,
  ) async {
    await addOrder(id: 'offline-review-123');
    await outbox.markFailed('offline-review-123', 'Không rõ kết quả gửi');
    final before = (await outbox.getById('offline-review-123'))!;
    await openPage(tester);
    await tester.tap(
      find.byKey(const ValueKey('offline-order-offline-review-123')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('CẦN KIỂM TRA'), findsOneWidget);
    expect(find.textContaining('Số lần thử đồng bộ:'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('copy-offline-request-id')),
      findsOneWidget,
    );

    final after = (await outbox.getById('offline-review-123'))!;
    expect(after.status, before.status);
    expect(after.attempts, before.attempts);
    expect(after.lastError, before.lastError);
    await closePage(tester);
  });

  testWidgets('Mở lại trang đọc lại Outbox, chỉ thấy đơn của actor', (
    tester,
  ) async {
    await addOrder(id: 'offline-page-mine');
    await addOrder(id: 'offline-page-other', actorId: 'other-employee');
    await openPage(tester);

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-mine')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-other')),
      findsNothing,
    );

    // Gỡ trang để hủy State/Future, nhưng giữ nguyên SQLite và GetX.
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));

    await outbox.markSynced('offline-page-mine');
    await tester.pumpWidget(const GetMaterialApp(home: OfflineOrdersPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-mine')),
      findsOneWidget,
    );
    expect(find.textContaining('Server đã xác nhận'), findsWidgets);
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-other')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await closePage(tester);
  });
  testWidgets('Tự cập nhật khi SQLite chuyển trạng thái không cần làm mới', (
    tester,
  ) async {
    await addOrder(id: 'offline-page-live-refresh');
    await openPage(tester);
    expect(find.textContaining('Chờ đồng bộ'), findsWidgets);
    expect(find.text('Chờ: 1'), findsOneWidget);

    await outbox.markSynced('offline-page-live-refresh');
    await tester.pumpAndSettle();

    expect(find.textContaining('Server đã xác nhận'), findsWidgets);
    expect(find.text('Chờ: 0'), findsOneWidget);
    expect(find.text('Đã xác nhận: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closePage(tester);
  });

  testWidgets('Tìm đơn bằng mã và tên khách hàng', (tester) async {
    await addOrder(id: 'offline-page-search-001');
    await addOrder(id: 'offline-page-other-002', actorId: 'other-employee');
    await openPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('offline-order-search')),
      'khong-co-don-nay',
    );
    await tester.pump();
    expect(find.text('Không tìm thấy đơn phù hợp.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('offline-order-search')),
      'Anh Minh',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-search-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-other-002')),
      findsNothing,
    );
    await closePage(tester);
  });

  testWidgets('Lọc theo trạng thái không thay đổi SQLite', (tester) async {
    await addOrder(id: 'offline-filter-pending');
    await addOrder(id: 'offline-filter-failed');
    await outbox.markFailed('offline-filter-failed', 'Cần xác minh');
    await openPage(tester);

    await tester.tap(find.byKey(const ValueKey('offline-filter-failed')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('offline-order-offline-filter-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offline-order-offline-filter-pending')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('offline-filter-all')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('offline-order-offline-filter-pending')),
      findsOneWidget,
    );
    expect((await outbox.getById('offline-filter-failed'))!.status, 'failed');
    await closePage(tester);
  });

  testWidgets('Xác minh thành công đánh dấu synced mà không gửi đơn', (
    tester,
  ) async {
    const id = 'verify-ok-001';
    await addOrder(id: id);
    await outbox.markFailed(id, 'Mất phản hồi');
    var verificationCalls = 0;
    Get.put<OutboxReconciler>(
      OutboxReconciler(
        outbox: outbox,
        verifyRequest: (requestId) async {
          verificationCalls++;
          expect(requestId, id);
          return const RequestVerification(
            status: RequestVerificationStatus.confirmed,
            orderId: 'server-order-001',
          );
        },
      ),
    );
    await openPage(tester);
    await tester.tap(find.byKey(const ValueKey('offline-order-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verify-offline-failed-order')));
    await tester.pumpAndSettle();
    expect(verificationCalls, 1);
    expect((await outbox.getById(id))!.status, 'synced');
    expect(find.text('Đã xác nhận: 1'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Firebase không tìm thấy vẫn giữ failed, không retry', (
    tester,
  ) async {
    const id = 'verify-missing-001';
    await addOrder(id: id);
    await outbox.markFailed(id, 'Mất phản hồi');
    final before = (await outbox.getById(id))!;
    Get.put<OutboxReconciler>(
      OutboxReconciler(
        outbox: outbox,
        verifyRequest: (_) async => const RequestVerification(
          status: RequestVerificationStatus.notFound,
        ),
      ),
    );
    await openPage(tester);
    await tester.tap(find.byKey(const ValueKey('offline-order-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verify-offline-failed-order')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase chưa tìm thấy đơn'), findsOneWidget);
    final after = (await outbox.getById(id))!;
    expect(after.status, 'failed');
    expect(after.attempts, before.attempts);
    await closePage(tester);
  });

  testWidgets('Đơn cần xác minh có phiếu đối chiếu, không đổi dữ liệu', (
    tester,
  ) async {
    const id = 'handoff-report-001';
    await addOrder(id: id);
    await outbox.markFailed(id, 'Cần xác minh phía server');
    final before = (await outbox.getById(id))!;
    await openPage(tester);
    await tester.tap(find.byKey(const ValueKey('offline-order-$id')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('copy-offline-review-report')),
      findsOneWidget,
    );
    expect(find.text('Sao chép phiếu đối chiếu'), findsOneWidget);
    final after = (await outbox.getById(id))!;
    expect(after.status, before.status);
    expect(after.attempts, before.attempts);
    expect(after.payloadJson, before.payloadJson);
    await closePage(tester);
  });

  testWidgets('Firebase chưa rõ kết quả vẫn giữ failed, không retry', (
    tester,
  ) async {
    const id = 'verify-uncertain-001';
    await addOrder(id: id);
    await outbox.markFailed(id, 'Mất phản hồi');
    final before = (await outbox.getById(id))!;
    Get.put<OutboxReconciler>(
      OutboxReconciler(
        outbox: outbox,
        verifyRequest: (_) async => const RequestVerification(
          status: RequestVerificationStatus.uncertain,
        ),
      ),
    );
    await openPage(tester);
    await tester.tap(find.byKey(const ValueKey('offline-order-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verify-offline-failed-order')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Chưa xác minh được trên Firebase'),
      findsOneWidget,
    );
    final after = (await outbox.getById(id))!;
    expect(after.status, 'failed');
    expect(after.attempts, before.attempts);
    await closePage(tester);
  });
}
