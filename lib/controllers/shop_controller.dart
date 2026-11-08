import 'dart:async';
import 'dart:collection';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data/demo_repository.dart';
import '../data/local/cart_draft_repository.dart';
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
  CartDraftRepository? _drafts;
  String? draftSaveError;

  void attachCartDrafts(CartDraftRepository drafts) {
    _drafts = drafts;
  }

  void _cartChanged() {
    if (_internalCartMutation ||
        !isLive ||
        actor == null ||
        cartEditingLocked) {
      return;
    }
    final drafts = _drafts;
    if (drafts == null) return;
    final owner = actor!.id;
    final id = requestId;
    final lines = cart
        .map(
          (l) => <String, Object?>{
            'productId': l.productId,
            'area': l.area,
            'note': l.note,
          },
        )
        .toList();
    final task = lines.isEmpty
        ? drafts.delete(owner)
        : drafts.save(actorId: owner, requestId: id, lines: lines);
    task.then(
      (_) {
        draftSaveError = null;
      },
      onError: (Object error) {
        draftSaveError = 'Không lưu được giỏ nháp trên máy: $error';
        update();
      },
    );
  }

  /// Khôi phục thủ công để không tự chèn hàng vào giỏ đã bắt đầu bán.
  /// Không phục hồi nháp nếu requestId đó đã nằm trong Outbox.
  Future<bool> restoreLocalDraft() async {
    final drafts = _drafts;
    final owner = actor?.id;
    if (!isLive || drafts == null || owner == null) return false;
    if (cart.isNotEmpty || busy || cartEditingLocked) return false;
    final generation = _session;
    final raw = await drafts.read(owner);
    if (raw == null) return false;
    final id = raw['requestId'];
    final storedLines = raw['lines'];
    if (id is! String ||
        id.isEmpty ||
        storedLines is! List ||
        storedLines.isEmpty) {
      throw const FormatException('Giỏ nháp không có dữ liệu hợp lệ.');
    }
    if (await _checkoutOutbox?.getById(id) != null) {
      // Đã lưu thành đơn: không được phục hồi như một giỏ chưa bán.
      return false;
    }
    final recovered = <CartLine>[];
    for (final entry in storedLines) {
      if (entry is! Map ||
          entry['productId'] is! String ||
          entry['area'] is! int ||
          entry['area'] <= 0 ||
          entry['note'] is! String) {
        throw const FormatException('Dữ liệu sản phẩm trong nháp bị lỗi.');
      }
      final productId = entry['productId'] as String;
      if (!data.products.any((p) => p.id == productId && p.active)) {
        throw StateError(
          'Sản phẩm trong giỏ nháp không còn khả dụng: $productId',
        );
      }
      recovered.add(
        CartLine(
          productId,
          entry['area'] as int,
          note: entry['note'] as String,
        ),
      );
    }
    if (generation != _session ||
        actor?.id != owner ||
        cart.isNotEmpty ||
        cartEditingLocked) {
      return false;
    }
    _internalCartMutation = true;
    try {
      _requestId = id;
      cart.addAll(recovered);
    } finally {
      _internalCartMutation = false;
    }
    update();
    return true;
  }

  bool _checkoutGuardRunning = false;
  bool _cartWriteLocked = false;
  bool _internalCartMutation = false;

  bool get cartEditingLocked =>
      isLive && (_cartWriteLocked || _checkoutGuardRunning);

  void _ensureCartEditable() {
    if (_internalCartMutation) return;
    if (cartEditingLocked) {
      throw StateError(
        'Giỏ hàng đang được xử lý hoặc đã lưu vào Outbox. '
        'Không được chỉnh sửa hay gửi lại mã giao dịch này.',
      );
    }
  }

  void _clearCartInternally() {
    _internalCartMutation = true;
    try {
      cart.clear();
    } finally {
      _internalCartMutation = false;
    }
  }

  /// Kết nối Outbox dùng để bảo vệ checkout online.
  void attachCheckoutOutbox(OutboxRepository outbox) {
    _checkoutOutbox = outbox;
  }

  bool get isLive => repository is TransactionalShopRepository;

  int page = 0;
  String query = '';
  String group = 'Tất cả';

  String _requestId = const Uuid().v4();
  String get requestId => _requestId;
  set requestId(String value) {
    if (value != _requestId && cartEditingLocked && !_internalCartMutation) {
      throw StateError('Không thể thay requestId của giỏ hàng đang khóa.');
    }
    _requestId = value;
  }

  late final List<CartLine> cart = _ProtectedCart(
    _ensureCartEditable,
    _cartChanged,
  );

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
    _clearCartInternally();
    _cartWriteLocked = false;

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
    _clearCartInternally();
    _cartWriteLocked = false;
    requestId = const Uuid().v4();

    update();
  }

  // ============================================================
  // CART
  // ============================================================

  void addCart(Product p, int area, {String? note}) {
    _ensureCartEditable();
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
    if (busy || _checkoutGuardRunning || _cartWriteLocked) {
      throw StateError('Đang xử lý hoặc đã lưu giao dịch này vào Outbox.');
    }

    final command = prepareOfflineCheckout(
      customerId: customerId,
      paid: paid,
      ship: ship,
      hold: hold,
      negativeReason: negativeReason,
    );

    final generation = _session;
    final currentActorId = actor!.id;
    _cartWriteLocked = true;
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

      // Đã lưu thành Outbox: nháp không còn là đơn đang nhập dở.
      // Lỗi xóa nháp không được coi là lỗi ghi Outbox để tránh gửi trùng.
      try {
        await _drafts?.delete(currentActorId);
      } catch (_) {}
      return command.requestId;
    } catch (_) {
      // Lỗi khi ghi Drift có thể xảy ra sau khi bản ghi đã được tạo.
      // Chỉ mở khóa nếu chắc chắn requestId chưa nằm trong Outbox.
      // Nếu DB không thể kiểm tra, giữ khóa theo nguyên tắc fail-closed.
      if (generation == _session) {
        try {
          final existing = await outbox.getById(command.requestId);
          if (existing == null) _cartWriteLocked = false;
        } catch (_) {
          // Trạng thái không rõ: không tự ý mở khóa.
        }
      }
      rethrow;
    } finally {
      busy = false;
      update();
    }
  }

  // ============================================================
  // START A FRESH CART AFTER THE PREVIOUS ORDER WAS SAVED
  // ============================================================

  /// Tạo giỏ hàng mới CHỈ khi đơn trước đã tồn tại trong SQLite Outbox.
  /// Không đồng bộ, không xóa/sửa bản ghi Outbox và không đánh dấu đã bán.
  ///
  /// Đọc và kiểm tra bản ghi trước khi bỏ giỏ cũ. Nếu việc đọc thất bại,
  /// giỏ hiện tại vẫn khóa để tránh mất thông tin giao dịch.
  Future<void> startNewCartAfterOfflineSave({
    required OutboxRepository outbox,
  }) async {
    if (!isLive || actor == null) {
      throw StateError('Cần đăng nhập tài khoản cửa hàng để tạo đơn mới.');
    }
    if (busy || _checkoutGuardRunning) {
      throw StateError('Đang xử lý giao dịch. Chưa thể tạo đơn mới.');
    }
    if (!_cartWriteLocked || cart.isEmpty) {
      throw StateError('Giỏ hiện tại chưa có đơn offline được lưu.');
    }

    final oldRequestId = requestId;
    final oldActorId = actor!.id;
    final generation = _session;
    _checkoutGuardRunning = true;
    busy = true;
    update();
    try {
      final saved = await outbox.getById(oldRequestId);
      if (saved == null || saved.operationType != 'checkout.v1') {
        throw StateError(
          'Không tìm thấy đơn đã lưu trong SQLite. Giỏ vẫn được khóa.',
        );
      }
      final OfflineCheckoutCommand command;
      try {
        command = OfflineCheckoutCommand.decode(saved.payloadJson);
      } catch (_) {
        throw StateError('Đơn đã lưu không đọc được. Giỏ vẫn được khóa.');
      }
      if (command.requestId != oldRequestId ||
          command.actorId != oldActorId ||
          command.lines.length != cart.length ||
          generation != _session ||
          actor?.id != oldActorId ||
          requestId != oldRequestId) {
        throw StateError('Đơn đã lưu không khớp phiên hoặc giỏ hàng hiện tại.');
      }
      for (var i = 0; i < cart.length; i++) {
        final savedLine = command.lines[i];
        final currentLine = cart[i];
        if (savedLine.productId != currentLine.productId ||
            savedLine.area != currentLine.area ||
            savedLine.note != currentLine.note) {
          throw StateError(
            'Sản phẩm trong giỏ khác đơn đã lưu. Giỏ vẫn được khóa.',
          );
        }
      }

      // Khi đã xác nhận bản ghi gốc, chỉ xóa giỏ trong bộ nhớ.
      // Đơn cũ vẫn tồn tại trong Outbox với requestId cũ để đồng bộ sau.
      _clearCartInternally();
      _requestId = const Uuid().v4();
      _cartWriteLocked = false;
      try {
        await _drafts?.delete(oldActorId);
      } catch (_) {}
    } finally {
      _checkoutGuardRunning = false;
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
    if (busy || _checkoutGuardRunning || _cartWriteLocked) {
      throw StateError('Giao dịch đang xử lý hoặc đã được lưu vào Outbox.');
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

      _clearCartInternally();
      _requestId = const Uuid().v4();
      try {
        if (actor != null) await _drafts?.delete(actor!.id);
      } catch (_) {}
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

/// Danh sách giỏ hàng có chặn ghi ở tầng controller.
/// Các thao tác thông qua c.cart (kể cả removeWhere/clear/[]=) đi qua guard.
class _ProtectedCart extends ListBase<CartLine> {
  _ProtectedCart(this._check, this._changed);

  final void Function() _check;
  final void Function() _changed;
  final List<CartLine> _items = <CartLine>[];

  @override
  int get length => _items.length;

  @override
  set length(int value) {
    _check();
    _items.length = value;
    _changed();
  }

  @override
  CartLine operator [](int index) => _items[index];

  @override
  void operator []=(int index, CartLine value) {
    _check();
    _items[index] = value;
    _changed();
  }

  @override
  void add(CartLine value) {
    _check();
    _items.add(value);
    _changed();
  }

  @override
  void addAll(Iterable<CartLine> values) {
    _check();
    _items.addAll(values);
    _changed();
  }

  @override
  void clear() {
    _check();
    _items.clear();
    _changed();
  }

  @override
  CartLine removeAt(int index) {
    _check();
    final result = _items.removeAt(index);
    _changed();
    return result;
  }

  @override
  void removeWhere(bool Function(CartLine) test) {
    _check();
    _items.removeWhere(test);
    _changed();
  }

  @override
  bool remove(Object? value) {
    _check();
    final didRemove = _items.remove(value);
    if (didRemove) _changed();
    return didRemove;
  }

  @override
  void retainWhere(bool Function(CartLine) test) {
    _check();
    _items.retainWhere(test);
    _changed();
  }

  @override
  void insert(int index, CartLine element) {
    _check();
    _items.insert(index, element);
    _changed();
  }

  @override
  void insertAll(int index, Iterable<CartLine> iterable) {
    _check();
    _items.insertAll(index, iterable);
    _changed();
  }

  @override
  void sort([int Function(CartLine, CartLine)? compare]) {
    _check();
    _items.sort(compare);
    _changed();
  }
}
