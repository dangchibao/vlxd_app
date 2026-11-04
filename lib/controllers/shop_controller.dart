import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data/demo_repository.dart';
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
  bool get isLive => repository is TransactionalShopRepository;
  int page = 0;
  String query = '', group = 'Tất cả';
  String requestId = const Uuid().v4();
  final List<CartLine> cart = [];
  ShopController(this.repository, this.data);
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
        syncError = 'Không đồng bộ được Firestore. Kiểm tra mạng, hồ sơ tài khoản và Security Rules. Dữ liệu chưa bị thay thế bằng mẫu.';
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
    if (busy) throw StateError('Đang lưu dữ liệu, vui lòng chờ.');
    final current = actor;
    if (current == null) throw StateError('Bạn chưa đăng nhập.');
    current.requireAccess();
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
            'Phiên đăng nhập đã thay đổi. Hãy kiểm tra lại lịch sử giao dịch.',
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
    if (isLive) throw StateError('Đăng xuất qua Firebase Authentication.');
    actor = null;
    cart.clear();
    requestId = const Uuid().v4();
    update();
  }

  void addCart(Product p, int area, {String? note}) {
    if (area <= 0) throw ArgumentError('Số lượng phải lớn hơn 0.');
    final nextNote = (note ?? p.note).trim();
    if (nextNote.length > 1000) {
      throw ArgumentError('Lưu ý tối đa 1.000 ký tự.');
    }
    final index = cart.indexWhere((l) => l.productId == p.id);
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
    (v, l) => v + lineMoney(l.area, data.product(l.productId).price),
  );
  Future<Json> checkout({
    required String customerId,
    required int paid,
    required int ship,
    bool hold = false,
    String negativeReason = '',
  }) async {
    final id = requestId;
    final lines = List<CartLine>.from(cart);
    final quoted = {
      for (final l in lines)
        l.productId: (
          price: data.product(l.productId).price,
          ratio: data.product(l.productId).ratio,
        ),
    };
    final result = await change((d, a) {
      if (!d.orders.any((o) => o['requestId'] == id)) {
        for (final entry in quoted.entries) {
          final product = d.product(entry.key);
          if (product.price != entry.value.price ||
              product.ratio != entry.value.ratio) {
            throw StateError(
              'Giá hoặc quy đổi vừa thay đổi. Kiểm tra lại giỏ hàng trước khi xác nhận.',
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
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
