part of 'app.dart';

Future<void> openDebtSettings(BuildContext context) async {
  final c = Get.find<ShopController>();
  final chosen = await safeDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Chọn sổ công nợ cần chỉnh'),
      children: [
        for (final customer in c.data.customers.where(
          (x) => x['active'] != false,
        ))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, customer['id']),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${customer['name']} • Còn nợ ${money(c.data.debt(customer['id']))}',
              ),
            ),
          ),
        if (!c.data.customers.any((x) => x['active'] != false))
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Thêm khách hàng trước khi chỉnh sổ công nợ.'),
          ),
      ],
    ),
  );
  if (chosen != null && context.mounted) {
    await editCustomerBook(context, chosen);
  }
}

Future<void> editCustomerBook(BuildContext context, String id) async {
  final c = Get.find<ShopController>();
  final customer = c.data.customers.firstWhere((x) => x['id'] == id);
  final before = c.data.customerBook(id);
  final total = TextEditingController(text: '${before.receivable}'),
      paid = TextEditingController(text: '${before.received}'),
      reason = TextEditingController();
  bool saving = false;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Chỉnh sổ công nợ • ${customer['name']}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Đã thu không được thấp hơn tổng phiếu thu hợp lệ. '
                  'Nếu ghi nhầm tiền, mở đơn hàng để sửa lần thu.',
                ),
                const SizedBox(height: 16),
                field(total, 'Phải thu (đ)', moneyInput: true),
                field(paid, 'Đã thu (đ)', moneyInput: true),
                field(reason, 'Lý do điều chỉnh (bắt buộc)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () => attempt(() async {
                    set(() => saving = true);
                    try {
                      await c.change(
                        (d, a) => d.adjustCustomerBook(
                          id,
                          whole(total.text),
                          whole(paid.text),
                          reason.text,
                          a,
                          expectedReceivable: before.receivable,
                          expectedReceived: before.received,
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } finally {
                      if (ctx.mounted) set(() => saving = false);
                    }
                  }),
            child: const Text('Lưu điều chỉnh'),
          ),
        ],
      ),
    ),
  );
  total.dispose();
  paid.dispose();
  reason.dispose();
}

Future<void> openPayrollSettings(BuildContext context) async {
  final c = Get.find<ShopController>();
  final chosen = await safeDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Quản lý lương nhân viên'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'create'),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('+ Tạo kỳ lương'),
          ),
        ),
        if (!c.data.payroll.any((p) => p['archived'] != true))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('Chưa có kỳ lương nào.'),
          ),
        for (final p in c.data.payroll.where((p) => p['archived'] != true))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p['id']),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('${p['name']} • ${p['period']}'),
            ),
          ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == 'create') {
    await createPayroll(context);
  } else {
    await editSalary(
      context,
      c.data.payroll.firstWhere((p) => p['id'] == chosen),
    );
  }
}

Future<void> deleteCustomer(BuildContext context, Json customer) async {
  final c = Get.find<ShopController>();
  if (!await confirm(
    context,
    'Xóa ${customer['name']} khỏi danh sách?',
    'Chỉ xóa khi không còn công nợ hoặc đơn giữ hàng. Hóa đơn và lịch sử vẫn được giữ.',
  )) {
    return;
  }
  await attempt(() => c.change((d, a) => d.archiveCustomer(customer['id'], a)));
}
