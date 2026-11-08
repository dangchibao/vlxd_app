import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data/demo_repository.dart';
import '../data/sync/offline_checkout_command.dart';
import '../data/sync/outbox_repository.dart';
import '../domain/shop.dart';

class ShopController extends GetxController {
  final ShopRepository repository;

  ShopData data;
  Actor? actor;

  bool busy = false;
  bool syncing = false;
  String? syncError;

  StreamSubscription<ShopData>? _subscription;
  int _session = 0;

  OutboxRepository? _checkoutOutbox;
  bool _checkoutGuardRunning = false;

  /// Kết nối Outbox dùng để bảo vệ checkout online.
  void attachCheckoutOutbox(OutboxRepository outbox) {
    _checkoutOutbox = outbox;
  }

  bool get isLive => repository is TransactionalShopRepository;

  int page = 0;
  String query = '';
  String group = 'Tất cả';

  String requestId = const Uuid().v4();

  final List<CartLine> cart = [];

  ShopController(this.repository, this.data);

  // ============================================================
  // SESSION / FIREBASE CONNECTION
  // ============================================================

  Future<void> connect(Actor user) async {
    final generation = ++_session;

    await _subscription?.cancel();

    if (generation != _session) return;

    actor = user;
    data = ShopData.empty();

    syncing = true;
    syncError = null;
    update();

    _subscription = (repository as TransactionalShopRepository).watch().listen(
      (next) {
        if (generation != _session) return;

        data = next;
        syncing = false;
        syncError = null;
        update();
      },
      onError: (Object error) {
        if (generation != _session) return;

        syncing = false;
        syncError =
            'Không đồng bộ được Firestore. '
            'Kiểm tra mạng, hồ sơ tài khoản và Security Rules. '
            'Dữ liệu chưa bị thay thế bằng mẫu.';

        update();
      },
    );
  }

  Future<void> clearSession() async {
    ++_session;

    await _subscription?.cancel();
    _subscription = null;

    actor = null;
    data = ShopData.empty();
    cart.clear();

    page = 0;
    requestId = const Uuid().v4();

    syncing = false;
    syncError = null;

    update();
  }

  // ============================================================
  // PRODUCT / SHOP DATA
  // ============================================================

  List<Product> get visibleProducts => data.products
      .where(
        (p) =>
            p.active &&
            (group == 'Tất cả' || p.size == group) &&
            '${p.code} ${p.name} ${p.supplier}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
      )
      .toList();

  Future<T> change<T>(T Function(ShopData d, Actor actor) operation) async {
    if (busy) {
      throw StateError('Đang lưu dữ liệu, vui lòng chờ.');
    }

    final current = actor;

    if (current == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    current.requireAccess();

    // Giữ nguyên cơ chế bảo vệ giao dịch online.
    if (syncing || syncError != null) {
      throw StateError('Chờ đồng bộ thành công trước khi ghi giao dịch.');
    }

    final generation = _session;

    busy = true;
    update();

    try {
      if (repository case final TransactionalShopRepository live) {
        final commit = await live.transact(operation, current);

        if (generation != _session) {
          throw StateError(
            'Phiên đăng nhập đã thay đổi. '
            'Hãy kiểm tra lại lịch sử giao dịch.',
          );
        }

        data = commit.data;
        return commit.result;
      } else {
        final next = data.copy();
        final result = operation(next, current);

        await repository.save(next);
        data = next;

        return result;
      }
    } finally {
      busy = false;
      update();
    }
  }

  // ============================================================
  // NAVIGATION / DEMO
  // ============================================================

  void navigate(int index) {
    page = index;
    query = '';
    group = 'Tất cả';
    update();
  }

  void enterDemo(Role role) {
    if (isLive) {
      throw StateError('Không chọn vai trò giả lập trên dữ liệu thật.');
    }

    actor = Actor(role == Role.owner ? 'admin' : 'Nhân viên mẫu', role);

    update();
  }

  void logout() {
    if (isLive) {
      throw StateError('Đăng xuất qua Firebase Authentication.');
    }

    actor = null;
    cart.clear();
    requestId = const Uuid().v4();

    update();
  }

  // ============================================================
  // CART
  // ============================================================

  void addCart(Product p, int area, {String? note}) {
    if (area <= 0) {
      throw ArgumentError('Số lượng phải lớn hơn 0.');
    }

    final nextNote = (note ?? p.note).trim();

    if (nextNote.length > 1000) {
      throw ArgumentError('Lưu ý tối đa 1.000 ký tự.');
    }

    final index = cart.indexWhere((line) => line.productId == p.id);

    if (index < 0) {
      cart.add(CartLine(p.id, area, note: nextNote));
    } else {
      final merged = mergeLineNotes([cart[index].note, nextNote]);

      if (merged.length > 1000) {
        throw ArgumentError('Lưu ý tối đa 1.000 ký tự.');
      }

      cart[index] = CartLine(p.id, cart[index].area + area, note: merged);
    }

    update();
  }

  int get subtotal => cart.fold(
    0,
    (total, line) =>
        total + lineMoney(line.area, data.product(line.productId).price),
  );

  // ============================================================
  // OFFLINE CHECKOUT - PREPARE
  // ============================================================

  /// Chuẩn bị lệnh checkout offline.
  ///
  /// Chỉ tạo dữ liệu, chưa lưu Drift hay gửi Firebase.
  /// Không xóa giỏ hàng hoặc thay đổi requestId.
  OfflineCheckoutCommand prepareOfflineCheckout({
    required String customerId,
    required int paid,
    required int ship,
    bool hold = false,
    String negativeReason = '',
  }) {
    if (!isLive) {
      throw StateError('Lệnh offline chỉ dành cho tài khoản Firebase.');
    }

    if (busy) {
      throw StateError('Đang xử lý giao dịch khác. Vui lòng chờ.');
    }

    final current = actor;

    if (current == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    current.requireAccess();

    if (cart.isEmpty) {
      throw StateError('Giỏ hàng đang trống.');
    }

    if (customerId.trim().isEmpty) {
      throw ArgumentError('Chưa chọn khách hàng.');
    }

    if (paid < 0 || ship < 0) {
      throw ArgumentError('Tiền thanh toán và phí giao hàng không được âm.');
    }

    final lines = <OfflineCheckoutLine>[];

    for (final line in cart) {
      if (line.area <= 0) {
        throw StateError('Số lượng sản phẩm phải lớn hơn 0.');
      }

      final product = data.product(line.productId);

      lines.add(
        OfflineCheckoutLine(
          productId: line.productId,
          area: line.area,
          note: line.note,
          quotedPrice: product.price,
          quotedRatio: product.ratio,
        ),
      );
    }

    return OfflineCheckoutCommand(
      requestId: requestId,
      actorId: current.id,
      customerId: customerId,
      lines: lines,
      paid: paid,
      ship: ship,
      hold: hold,
      negativeReason: negativeReason,
      createdAt: DateTime.now().toUtc(),
    );
  }

  // ============================================================
  // OFFLINE CHECKOUT - SAVE TO OUTBOX
  // ============================================================

  /// Lưu lệnh bán hàng vào Drift Outbox.
  ///
  /// Chưa gửi Firebase.
  /// Chưa xác nhận đơn hàng đã được chốt.
  /// Không tự động retry khi kết quả chưa rõ ràng.
  ///
  /// Hàm này chưa được nối với nút Chốt đơn.
  Future<String> queueOfflineCheckout({
    required OutboxRepository outbox,
    required String customerId,
    required int paid,
    required int ship,
    bool hold = false,
    String negativeReason = '',
  }) async {
    if (busy || _checkoutGuardRunning) {
      throw StateError('Đang xử lý giao dịch khác. Vui lòng chờ.');
    }

    final command = prepareOfflineCheckout(
      customerId: customerId,
      paid: paid,
      ship: ship,
      hold: hold,
      negativeReason: negativeReason,
    );

    final generation = _session;
    busy = true;
    update();

    try {
      // Chỉ lưu vào Drift. Không tự động gửi Firebase.
      await outbox.enqueueCheckout(command);

      if (generation != _session) {
        throw StateError(
          'Phiên đăng nhập đã thay đổi sau khi lưu Outbox. '
          'Cần kiểm tra giao dịch đã lưu trước khi tiếp tục.',
        );
      }

      // Đây là requestId chờ đồng bộ, không phải hóa đơn đã xác nhận.
      return command.requestId;
    } finally {
      busy = false;
      update();
    }
  }

  // ============================================================
  // ONLINE CHECKOUT - KEEP EXISTING BEHAVIOR
  // ============================================================

  Future<Json> checkout({
    required String customerId,
    required int paid,
    required int ship,
    bool hold = false,
    String negativeReason = '',
  }) async {
    if (busy || _checkoutGuardRunning) {
      throw StateError('Đang xử lý giao dịch khác. Vui lòng chờ.');
    }

    _checkoutGuardRunning = true;
    try {
      final id = requestId;

      // Không cho lệnh đã được ghi vào Outbox đi qua checkout online.
      // Với Live phải có Outbox để xác minh; Demo không cần.
      if (isLive) {
        final outbox = _checkoutOutbox;
        if (outbox == null) {
          throw StateError(
            'Chưa kết nối Outbox. Không thể xác minh giao dịch trước khi chốt.',
          );
        }

        final existing = await outbox.getById(id);
        if (existing != null) {
          throw StateError(
            'Giao dịch $id đã nằm trong Outbox '
            '(trạng thái: ${existing.status}). '
            'Hãy kiểm tra lịch sử và trạng thái đồng bộ trước khi tiếp tục.',
          );
        }
      }

      final lines = List<CartLine>.from(cart);
      final quoted = {
        for (final line in lines)
          line.productId: (
            price: data.product(line.productId).price,
            ratio: data.product(line.productId).ratio,
          ),
      };

      final result = await change((d, a) {
        if (!d.orders.any((order) => order['requestId'] == id)) {
          for (final entry in quoted.entries) {
            final product = d.product(entry.key);
            if (product.price != entry.value.price ||
                product.ratio != entry.value.ratio) {
              throw StateError(
                'Giá hoặc quy đổi vừa thay đổi. '
                'Kiểm tra lại giỏ hàng trước khi xác nhận.',
              );
            }
          }
        }
        return d.checkout(
          requestId: id,
          lines: lines,
          customerId: customerId,
          paid: paid,
          ship: ship,
          hold: hold,
          actor: a,
          negativeReason: negativeReason,
        );
      });

      cart.clear();
      requestId = const Uuid().v4();
      update();
      return result;
    } finally {
      _checkoutGuardRunning = false;
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
