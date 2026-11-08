part of 'app.dart';

Future<void> createPayroll(BuildContext context) async {
  final name = TextEditingController(),
      period = TextEditingController(
        text: DateFormat('MM/yyyy').format(DateTime.now()),
      ),
      salary = TextEditingController(),
      advance = TextEditingController(text: '0');
  final id = newId();
  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tạo kỳ lương nhân viên'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(name, 'Tên nhân viên'),
              field(period, 'Kỳ lương MM/yyyy'),
              field(salary, 'Lương kỳ này (đ)', moneyInput: true),
              field(advance, 'Đã ứng / đã trả (đ)', moneyInput: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => attempt(() async {
            final pay = whole(salary.text), paid = whole(advance.text);
            if (name.text.trim().isEmpty ||
                !RegExp(r'^(0[1-9]|1[0-2])/20\d{2}$').hasMatch(period.text) ||
                pay < 0 ||
                paid < 0 ||
                paid > pay) {
              throw ArgumentError(
                'Kiểm tra tên, kỳ MM/yyyy và số tiền hợp lệ.',
              );
            }
            await Get.find<ShopController>().change((d, actor) {
              actor.requireAccess();
              if (d.payroll.any((p) => p['id'] == id)) return;
              if (d.payroll.any(
                (p) =>
                    p['name'] == name.text.trim() && p['period'] == period.text,
              )) {
                throw StateError('Nhân viên này đã có kỳ lương tương ứng.');
              }
              d.payroll.add({
                'id': id,
                'name': name.text.trim(),
                'period': period.text,
                'salary': pay,
                'advance': paid,
              });
              d.log(
                actor,
                'Tạo kỳ lương',
                id,
                '${name.text.trim()} • ${period.text} • $pay đ',
              );
            });
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('Lưu kỳ lương'),
        ),
      ],
    ),
  );
  for (final c in [name, period, salary, advance]) {
    c.dispose();
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String query = '', status = 'Tất cả';
  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (c) {
      final orders = c.data.orders
          .where(
            (o) =>
                (status == 'Tất cả' || o['status'] == status) &&
                '${o['id']} ${o['customerId']}'.toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử đơn hàng')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm mã đơn hoặc mã khách',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Tất cả', 'Giữ hàng', 'Đã bán', 'Đã hủy']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: status == v,
                      onSelected: (_) => setState(() => status = v),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              const EmptyState(
                'Chưa có đơn phù hợp',
                'Thử bộ lọc hoặc mã khác.',
                Icons.receipt_long_outlined,
              ),
            ...orders.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: panel(
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${o['id']} • ${o['status']}'),
                    subtitle: Text(
                      '${day(o['at'])}\nThu ròng ${money(ShopData.netCollected(o))}',
                    ),
                    isThreeLine: true,
                    trailing: Text(money(o['total'])),
                    onTap: () => showOrder(context, o),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> correctPaymentDialog(
  BuildContext context,
  Json o,
  Json payment,
) async {
  final amount = TextEditingController(text: '${payment['amount']}'),
      reason = TextEditingController();
  final correctionId = newId();
  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sửa hoặc xóa lần thu'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đang ghi ${money(payment['amount'])}. Nhập 0 để hủy lần thu, nhập số mới để điều chỉnh. Bản ghi cũ vẫn giữ trong lịch sử.',
              ),
              const SizedBox(height: 16),
              field(amount, 'Số tiền thay thế (đ)', moneyInput: true),
              field(reason, 'Lý do điều chỉnh'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => attempt(() async {
            await Get.find<ShopController>().change(
              (d, a) => d.correctPayment(
                o['id'],
                payment['id'],
                whole(amount.text),
                reason.text,
                correctionId,
                a,
              ),
            );
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('Ghi điều chỉnh'),
        ),
      ],
    ),
  );
  amount.dispose();
  reason.dispose();
}

Future<void> cancelHeldDialog(BuildContext context, Json o) async {
  final reason = TextEditingController();
  bool refunded = false;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Hủy giữ hàng và hoàn cọc'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Giải phóng hàng đang giữ. Tiền cần hoàn: ${money(ShopData.collected(o))}.',
              ),
              const SizedBox(height: 16),
              field(reason, 'Lý do hủy'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: refunded,
                onChanged: (v) => set(() => refunded = v!),
                title: const Text('Đã hoàn tiền cọc cho khách (nếu có)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: !refunded
                ? null
                : () => attempt(() async {
                    await Get.find<ShopController>().change(
                      (d, a) => d.cancelHeld(o['id'], reason.text, a),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }),
            child: const Text('Xác nhận hủy giữ'),
          ),
        ],
      ),
    ),
  );
  reason.dispose();
}
