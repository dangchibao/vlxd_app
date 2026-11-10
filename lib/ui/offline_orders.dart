import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/shop_controller.dart';
import '../data/local/app_database.dart';
import '../data/sync/offline_checkout_command.dart';
import '../data/sync/outbox_repository.dart';
import '../data/sync/outbox_reconciler.dart';
import '../data/sync/offline_book_operation.dart';
import '../data/sync/auto_sync_coordinator.dart';

/// Màn hình CHỈ ĐỌC các giao dịch đã lưu trên thiết bị.
/// Không gọi SyncRuntime, SyncEngine, retryFailed hay xóa bản ghi.
class OfflineOrdersPage extends StatefulWidget {
  const OfflineOrdersPage({super.key});

  @override
  State<OfflineOrdersPage> createState() => _OfflineOrdersPageState();
}

class _OfflineOrdersPageState extends State<OfflineOrdersPage> {
  late Stream<List<PendingOperation>> _operations;
  String _searchText = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _operations = _watchOperations();
  }

  Stream<List<PendingOperation>> _watchOperations() {
    if (!Get.isRegistered<OutboxRepository>()) {
      throw StateError('Outbox chưa được khởi tạo trên thiết bị này.');
    }
    if (!Get.isRegistered<ShopController>()) {
      throw StateError('Phiên bán hàng chưa sẵn sàng.');
    }
    final actor = Get.find<ShopController>().actor;
    if (actor == null) {
      throw StateError('Vui lòng đăng nhập để xem đơn offline.');
    }

    final outbox = Get.find<OutboxRepository>();
    return outbox.db.select(outbox.db.pendingOperations).watch().map((all) {
      final visible = <PendingOperation>[];
      visible.addAll(
        all.where((row) => offlineOperationOwner(row) == actor.id),
      );
      visible.sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
      return visible;
    });
  }

  // Tên chỉ được tra từ dữ liệu hiện có trên máy, không gọi Firebase.
  // Các đơn cũ chưa lưu snapshot tên nên tên hiện tại có thể khác lúc bán.
  String _customerName(String id) {
    if (id.isEmpty) return 'Khách lẻ';
    final customers = Get.find<ShopController>().data.customers;
    for (final customer in customers) {
      if (customer['id'] == id) {
        final name = (customer['name'] as String? ?? '').trim();
        if (name.isNotEmpty) return name;
      }
    }
    return 'Chưa có tên khách hàng';
  }

  Future<void> _retry(String id) async {
    try {
      final message = await Get.find<AutoSyncCoordinator>().reviewAndRetry(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _cancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ giao dịch chờ đồng bộ?'),
        content: const Text(
          'Giao dịch sẽ được giữ trong lịch sử trên máy. Bạn có thể nhập lại theo thông tin đã đối chiếu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ giao dịch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Get.find<AutoSyncCoordinator>().cancelReviewed(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _bookTile(PendingOperation row) {
    final command = OfflineBookOperation.decode(row);
    final detail = command.type == OfflineBookOperation.payment
        ? 'Đơn ${command.target} • ${_money(command.amount)}'
        : '${_productName(command.target)} • ${command.amount / 10000} ${command.unit}';
    return Card(
      child: ListTile(
        title: Text('${command.label} • ${_shortReference(row.id)}'),
        subtitle: Text(
          '$detail\n${_statusText(row.status)}${row.status == 'failed' ? '\n${row.lastError ?? ''}' : ''}',
        ),
        trailing: Get.isRegistered<AutoSyncCoordinator>()
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.status == 'failed')
                    IconButton(
                      tooltip: 'Xác minh và gửi lại',
                      onPressed: () => _retry(row.id),
                      icon: const Icon(Icons.sync),
                    ),
                  if (OutboxRepository.canCancel(row))
                    IconButton(
                      tooltip: 'Bỏ giao dịch',
                      onPressed: () => _cancel(row.id),
                      icon: const Icon(Icons.close),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  String _staffName(String id) {
    final actor = Get.find<ShopController>().actor;
    if (actor != null && actor.id == id) {
      final name = actor.displayName?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Chưa có tên nhân viên đã lưu';
  }

  String _productName(String id) {
    final products = Get.find<ShopController>().data.products;
    for (final product in products) {
      if (product.id == id) {
        return '${product.name} ${product.size}'.trim();
      }
    }
    return 'Sản phẩm không còn trong danh mục';
  }

  // Chỉ là mã tham chiếu dễ nhìn, KHÔNG thay thế requestId duy nhất.
  String _shortReference(String id) {
    final fragment = id.replaceAll('-', '').toUpperCase();
    return 'OFF-${fragment.length > 8 ? fragment.substring(0, 8) : fragment}';
  }

  String _money(num amount) =>
      '${NumberFormat.decimalPattern('vi_VN').format(amount)} đ';

  String _statusText(String status) => switch (status) {
    'pending' => 'Chờ đồng bộ',
    'syncing' => 'Đang xử lý',
    'failed' => 'Cần xác minh',
    'synced' => 'Server đã xác nhận',
    'cancelled' => 'Đã bỏ trên máy',
    _ => 'Trạng thái: $status',
  };

  Color _statusColor(String status) => switch (status) {
    'pending' => const Color(0xFFAA6900),
    'syncing' => const Color(0xFF086EEB),
    'failed' => const Color(0xFFB3261E),
    'synced' => const Color(0xFF168366),
    _ => Colors.grey,
  };

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // Phiếu đối chiếu là bản ghi chẩn đoán, không phải hóa đơn hay lệnh gửi lại.
  // Chỉ chứa mã kỹ thuật và thông tin của giao dịch để quản lý đối chiếu.
  String _reviewReport(
    PendingOperation operation,
    OfflineCheckoutCommand command,
  ) {
    final lines = <String>[
      'VLXD BAY HAI - PHIEU DOI CHIEU DON OFFLINE',
      'KHONG PHAI HOA DON - KHONG TU GUI LAI',
      'Ma tham chieu: ${_shortReference(operation.id)}',
      'Request ID: ${operation.id}',
      'Trang thai tren may: ${_statusText(operation.status)}',
      'So lan thu: ${operation.attempts}',
      'Thoi diem luu: ${_date(operation.createdAt)}',
      'Ma khach hang: ${command.customerId}',
      'UID nhan vien: ${command.actorId}',
      'Da thu: ${_money(command.paid)}',
      'Phi giao hang: ${_money(command.ship)}',
      if (command.discount > 0) 'Giam gia: ${_money(command.discount)}',
      'Giu hang: ${command.hold ? 'Co' : 'Khong'}',
      'San pham:',
      for (final line in command.lines)
        '- ${line.productId} | so luong quy doi ${line.area} | '
            'don gia ${_money(line.quotedPrice)} | he so ${line.quotedRatio}',
      if (operation.lastError != null && operation.lastError!.isNotEmpty)
        'Loi dong bo: ${operation.lastError}',
      'DOI CHIEU REQUEST ID VA TON KHO TREN FIREBASE TRUOC KHI XU LY.',
    ];
    return lines.join('\n');
  }

  void _showDetails(PendingOperation operation) {
    final command = OfflineCheckoutCommand.decode(operation.payloadJson);
    var verifying = false;
    String? verifyMessage;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateDialog) => AlertDialog(
          title: const Text('Chi tiết đơn offline'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mã tham chiếu: ${_shortReference(operation.id)}'),
                  SelectableText('Request ID (kỹ thuật): ${operation.id}'),
                  const SizedBox(height: 8),
                  Text('Trạng thái: ${_statusText(operation.status)}'),
                  if (operation.status == 'failed') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'CẦN KIỂM TRA: Không tự tạo lại đơn. Quản lý cần đối chiếu '
                        'Request ID trên Firebase và xác minh hóa đơn, tồn kho '
                        'trước khi quyết định xử lý.',
                        style: TextStyle(
                          color: Color(0xFF8A3B00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (verifyMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      verifyMessage!,
                      key: const ValueKey('offline-verification-result'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  Text('Số lần thử đồng bộ: ${operation.attempts}'),
                  Text('Lưu lúc: ${_date(operation.createdAt)}'),
                  Text('Khách hàng: ${_customerName(command.customerId)}'),
                  Text('Mã khách hàng: ${command.customerId}'),
                  Text('Nhân viên: ${_staffName(command.actorId)}'),
                  Text('UID nhân viên: ${command.actorId}'),
                  Text('Tiền đã thu: ${_money(command.paid)}'),
                  Text('Phí giao hàng: ${_money(command.ship)}'),
                  if (command.discount > 0)
                    Text('Giảm giá: ${_money(command.discount)}'),
                  Text('Giữ hàng / đặt cọc: ${command.hold ? 'Có' : 'Không'}'),
                  if (command.negativeReason.isNotEmpty)
                    Text('Lý do bán âm: ${command.negativeReason}'),
                  if (operation.lastError != null &&
                      operation.lastError!.isNotEmpty)
                    Text('Ghi chú đồng bộ: ${operation.lastError}'),
                  const Divider(height: 24),
                  const Text(
                    'Sản phẩm (giá và quy đổi tại lúc lưu)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final line in command.lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_productName(line.productId)),
                      subtitle: Text(
                        'Mã sản phẩm: ${line.productId}\n'
                        'Số lượng quy đổi: ${line.area}\n'
                        'Đơn giá khi lưu: ${_money(line.quotedPrice)} / đơn vị\n'
                        'Hệ số quy đổi: ${line.quotedRatio}'
                        '${line.note.isEmpty ? '' : '\nGhi chú: ${line.note}'}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đây là lệnh lưu trên thiết bị. Chưa được coi là hóa đơn '
                    'hoàn tất nếu server chưa xác nhận.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (OutboxRepository.canCancel(operation) &&
                Get.isRegistered<AutoSyncCoordinator>())
              TextButton(
                onPressed: verifying
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _cancel(operation.id);
                      },
                child: const Text('Bỏ giao dịch'),
              ),
            if (operation.status == 'failed' &&
                Get.isRegistered<AutoSyncCoordinator>())
              TextButton(
                onPressed: verifying
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _retry(operation.id);
                      },
                child: const Text('Xác minh và gửi lại'),
              ),
            if (operation.status == 'failed')
              OutlinedButton.icon(
                key: const ValueKey('verify-offline-failed-order'),
                onPressed: verifying
                    ? null
                    : () async {
                        updateDialog(() {
                          verifying = true;
                          verifyMessage = null;
                        });
                        String message;
                        var confirmed = false;
                        try {
                          if (!Get.isRegistered<OutboxReconciler>() ||
                              !Get.isRegistered<OutboxRepository>() ||
                              !Get.isRegistered<ShopController>()) {
                            throw StateError(
                              'Chưa sẵn sàng xác minh Firebase.',
                            );
                          }
                          final actor = Get.find<ShopController>().actor;
                          final outbox = Get.find<OutboxRepository>();
                          final current = await outbox.getById(operation.id);
                          if (actor == null ||
                              actor.id != command.actorId ||
                              current == null ||
                              current.status != 'failed' ||
                              current.operationType != 'checkout.v1' ||
                              current.payloadJson != operation.payloadJson) {
                            throw StateError(
                              'Đơn hoặc phiên đăng nhập đã thay đổi. Mở lại danh sách để kiểm tra.',
                            );
                          }
                          final result = await Get.find<OutboxReconciler>()
                              .reconcile(operation.id);
                          switch (result) {
                            case ReconcileResult.confirmed:
                              final refreshed = await outbox.getById(
                                operation.id,
                              );
                              confirmed = refreshed?.status == 'synced';
                              message = confirmed
                                  ? 'Firebase đã xác nhận. Đơn chuyển sang Đã đồng bộ.'
                                  : 'Chưa xác nhận được trạng thái lưu trên máy.';
                            case ReconcileResult.notFound:
                              message = 'Firebase chưa tìm thấy đơn. Giữ nguyên trạng thái Cần xác minh; không tự gửi lại.';
                            case ReconcileResult.uncertain:
                              message = 'Chưa xác minh được trên Firebase (mạng, quyền hoặc dữ liệu). Không gửi lại đơn.';
                            case ReconcileResult.unsupported:
                              message = 'Loại đơn chưa được hỗ trợ xác minh.';
                          }
                        } catch (error) {
                          message = 'Không thể kiểm tra: $error';
                        }
                        if (!ctx.mounted) return;
                        updateDialog(() {
                          verifying = false;
                          verifyMessage = message;
                        });
                        if (confirmed) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.maybeOf(
                              context,
                            )?.showSnackBar(SnackBar(content: Text(message)));
                          }
                        }
                      },
                icon: verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_done_outlined),
                label: const Text('Kiểm tra trên Firebase'),
              ),
            if (operation.status == 'failed')
              TextButton.icon(
                key: const ValueKey('copy-offline-review-report'),
                onPressed: verifying
                    ? null
                    : () async {
                        // Không sửa Outbox hay gọi mạng. Chỉ sao chép dữ liệu.
                        await Clipboard.setData(
                          ClipboardData(
                            text: _reviewReport(operation, command),
                          ),
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã sao chép phiếu đối chiếu cho quản lý',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Sao chép phiếu đối chiếu'),
              ),
            TextButton.icon(
              key: const ValueKey('copy-offline-request-id'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: operation.id));
                if (!ctx.mounted) return;
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã giao dịch')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Sao chép mã giao dịch'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đơn chờ đồng bộ'),
      actions: [
        if (Get.isRegistered<AutoSyncCoordinator>())
          IconButton(
            tooltip: 'Đồng bộ ngay',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await Get.find<AutoSyncCoordinator>().checkNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã kiểm tra hàng đợi. Xem trạng thái từng giao dịch.',
                    ),
                  ),
                );
              }
            },
          ),
        IconButton(
          tooltip: 'Làm mới danh sách',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_reload),
        ),
      ],
    ),
    body: StreamBuilder<List<PendingOperation>>(
      stream: _operations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Không thể đọc đơn offline: ${snapshot.error}'),
            ),
          );
        }
        final items = snapshot.data ?? const <PendingOperation>[];
        if (items.isEmpty) {
          return const Center(
            child: Text('Chưa có đơn offline của tài khoản này trên thiết bị.'),
          );
        }
        final pendingCount = items
            .where((item) => item.status == 'pending')
            .length;
        final needsReviewCount = items
            .where((item) => item.status == 'failed')
            .length;
        final syncedCount = items
            .where((item) => item.status == 'synced')
            .length;
        final search = _searchText.trim().toLowerCase();
        final filtered = items.where((operation) {
          if (_statusFilter != 'all' && operation.status != _statusFilter) {
            return false;
          }
          if (search.isEmpty) return true;
          if (OfflineBookOperation.supports(operation.operationType)) {
            final command = OfflineBookOperation.decode(operation);
            return '${command.label} ${command.target} ${operation.id} ${_productName(command.target)}'
                .toLowerCase()
                .contains(search);
          }
          final command = OfflineCheckoutCommand.decode(operation.payloadJson);
          final searchable = <String>[
            operation.id,
            _shortReference(operation.id),
            command.customerId,
            _customerName(command.customerId),
            for (final line in command.lines) ...[
              line.productId,
              _productName(line.productId),
            ],
          ].join(' ').toLowerCase();
          return searchable.contains(search);
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Danh sách tự cập nhật khi trạng thái trên máy thay đổi.',
                    style: TextStyle(color: Color(0xFF526780), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('offline-order-search'),
                    decoration: const InputDecoration(
                      labelText: 'Tìm đơn offline',
                      hintText: 'Mã đơn, tên khách hoặc sản phẩm',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchText = value),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in const <(String, String)>[
                          ('all', 'Tất cả'),
                          ('pending', 'Chờ đồng bộ'),
                          ('syncing', 'Đang xử lý'),
                          ('failed', 'Cần kiểm tra'),
                          ('synced', 'Đã xác nhận'),
                          ('cancelled', 'Đã bỏ'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey('offline-filter-${filter.$1}'),
                              label: Text(filter.$2),
                              selected: _statusFilter == filter.$1,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = filter.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text('Chờ: $pendingCount'),
                        backgroundColor: const Color(0xFFFFF2D8),
                      ),
                      Chip(
                        label: Text('Cần kiểm tra: $needsReviewCount'),
                        backgroundColor: const Color(0xFFFFE5E3),
                      ),
                      Chip(
                        label: Text('Đã xác nhận: $syncedCount'),
                        backgroundColor: const Color(0xFFE4F5EC),
                      ),
                    ],
                  ),
                  if (needsReviewCount > 0)
                    const Text(
                      'Đơn cần kiểm tra không tự gửi lại. Hãy đối chiếu Firebase trước khi xử lý.',
                      style: TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Không tìm thấy đơn phù hợp.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final operation = filtered[index];
                        if (OfflineBookOperation.supports(
                          operation.operationType,
                        )) {
                          return _bookTile(operation);
                        }
                        final command = OfflineCheckoutCommand.decode(
                          operation.payloadJson,
                        );
                        return Card(
                          child: ListTile(
                            key: ValueKey('offline-order-${operation.id}'),
                            title: Text(
                              'Mã tham chiếu ${_shortReference(operation.id)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_date(operation.createdAt)} · Khách ${_customerName(command.customerId)}\n'
                              '${command.lines.length} mặt hàng · ${_statusText(operation.status)}',
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              Icons.circle,
                              size: 15,
                              color: _statusColor(operation.status),
                            ),
                            onTap: () => _showDetails(operation),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}
