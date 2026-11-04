part of 'app.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Get.find<SessionController>();
    if (Get.find<ShopController>().actor?.canAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Chỉ chủ quản lý tài khoản.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản và phân quyền')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => createAccount(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Tạo tài khoản'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Json>>(
              stream: s.firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    'Không đọc được tài khoản',
                    'Kiểm tra quyền chủ và Security Rules.',
                    Icons.lock_outline,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final user = doc.data(),
                        self = doc.id == s.auth.currentUser?.uid;
                    return ListTile(
                      title: Text(user['displayName'] ?? doc.id),
                      subtitle: Text(
                        '${user['role']} • ${user['active'] == true ? 'Hoạt động' : 'Đã khóa'}${self ? ' • Bạn' : ''}',
                      ),
                      trailing: self
                          ? null
                          : IconButton(
                              tooltip: 'Sửa quyền / khóa tài khoản',
                              icon: const Icon(Icons.manage_accounts_outlined),
                              onPressed: () =>
                                  editAccount(context, doc.id, user),
                            ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Tài xế / vị trí khác lưu được hồ sơ nhưng chưa vào nghiệp vụ. Đặt lại mật khẩu cho người khác cần công cụ quản trị tin cậy; không thực hiện từ quyền Firebase client.',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> createAccount(BuildContext context) async {
  final account = TextEditingController(),
      name = TextEditingController(),
      password = TextEditingController();
  var role = 'sales', saving = false;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Tạo tài khoản nhân sự'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(name, 'Họ tên'),
                field(account, 'SĐT / tên tài khoản / email'),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu tạm • ít nhất 10 ký tự',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(
                      value: 'sales',
                      child: Text('Nhân viên bán hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'driver',
                      child: Text('Tài xế • chưa truy cập'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Vị trí khác • chưa truy cập'),
                    ),
                  ],
                  onChanged: (v) => role = v!,
                ),
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
                    final s = Get.find<SessionController>();
                    Get.find<ShopController>().actor!.requireAdmin();
                    if (name.text.trim().isEmpty || password.text.length < 10) {
                      throw ArgumentError(
                        'Nhập họ tên và mật khẩu tạm ít nhất 10 ký tự.',
                      );
                    }
                    final email = loginEmail(account.text);
                    set(() => saving = true);
                    FirebaseApp? secondary;
                    User? created;
                    try {
                      secondary = await Firebase.initializeApp(
                        name: 'staff-${newId()}',
                        options: s.auth.app.options,
                      );
                      final auth = FirebaseAuth.instanceFor(app: secondary);
                      const emulated = bool.fromEnvironment(
                        'USE_FIREBASE_EMULATOR',
                      );
                      if (emulated) {
                        await auth.useAuthEmulator(
                          const String.fromEnvironment(
                            'FIREBASE_EMULATOR_HOST',
                            defaultValue: '127.0.0.1',
                          ),
                          9099,
                        );
                      }
                      created = (await auth.createUserWithEmailAndPassword(
                        email: email,
                        password: password.text,
                      )).user;
                      final batch = s.firestore.batch();
                      batch.set(s.firestore.doc('users/${created!.uid}'), {
                        'displayName': name.text.trim(),
                        'role': role,
                        'active': true,
                        'mustChangePassword': true,
                      });
                      batch.set(s.firestore.doc('accountAudit/${newId()}'), {
                        'actor': s.auth.currentUser!.uid,
                        'target': created.uid,
                        'action': 'Tạo tài khoản',
                        'at': FieldValue.serverTimestamp(),
                      });
                      await batch.commit();
                      await auth.signOut();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (created != null) {
                        throw StateError(
                          'Auth đã tạo UID ${created.uid}, nhưng chưa xác nhận được hồ sơ quyền. Không tạo lại; chủ cần đối chiếu UID trong Console. Không có quyền tự động cấp.',
                        );
                      }
                      rethrow;
                    } finally {
                      await secondary?.delete();
                      if (ctx.mounted) set(() => saving = false);
                    }
                  }),
            child: const Text('Tạo và cấp quyền'),
          ),
        ],
      ),
    ),
  );
  account.dispose();
  name.dispose();
  password.dispose();
}

Future<void> editAccount(BuildContext context, String uid, Json profile) async {
  var role = profile['role'] as String, active = profile['active'] == true;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(profile['displayName'] ?? uid),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: const [
                DropdownMenuItem(value: 'owner', child: Text('Chủ cửa hàng')),
                DropdownMenuItem(
                  value: 'sales',
                  child: Text('Nhân viên bán hàng'),
                ),
                DropdownMenuItem(value: 'driver', child: Text('Tài xế')),
                DropdownMenuItem(value: 'other', child: Text('Vị trí khác')),
              ],
              onChanged: (v) => role = v!,
            ),
            SwitchListTile(
              title: const Text('Cho phép tài khoản hoạt động'),
              value: active,
              onChanged: (v) => set(() => active = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => attempt(() async {
              final s = Get.find<SessionController>();
              Get.find<ShopController>().actor!.requireAdmin();
              await s.firestore.runTransaction((tx) async {
                final ref = s.firestore.doc('users/$uid'),
                    current = await tx.get(s.firestore.doc('users/$uid'));
                if (jsonEncode(current.data()) != jsonEncode(profile)) {
                  throw StateError(
                    'Quyền đã thay đổi, mở lại thông tin tài khoản.',
                  );
                }
                tx.update(ref, {'role': role, 'active': active});
                tx.set(s.firestore.doc('accountAudit/${newId()}'), {
                  'actor': s.auth.currentUser!.uid,
                  'target': uid,
                  'action': 'Đổi quyền / khóa',
                  'beforeRole': profile['role'],
                  'afterRole': role,
                  'active': active,
                  'at': FieldValue.serverTimestamp(),
                });
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: const Text('Lưu quyền'),
          ),
        ],
      ),
    ),
  );
}

Future<void> importLocalDemo(BuildContext context) async {
  final c = Get.find<ShopController>();
  c.actor!.requireAdmin();
  if (!c.isLive) throw StateError('Chỉ nhập khi đang kết nối Firestore thật.');
  final raw = await SharedPreferencesAsync().getString(DemoRepository.key);
  if (raw == null) {
    throw StateError(
      'Không có dữ liệu mẫu đã lưu trên thiết bị này. Không tự sinh hoặc tải dữ liệu mẫu lên Firestore.',
    );
  }
  final source = ShopData.fromJson(jsonDecode(raw));
  if (!context.mounted) return;
  if (!await confirm(
    context,
    'Nhập dữ liệu cục bộ vào kho đang trống?',
    '${source.products.length} sản phẩm • ${source.orders.length} đơn • ${source.customers.length} khách\nChỉ thực hiện khi tất cả dữ liệu đích đều trống. Lịch sử được đánh dấu nhập từ bản mẫu; dữ liệu cục bộ vẫn giữ nguyên.',
  )) {
    return;
  }
  await c.change((target, actor) {
    if (target
        .toJson()
        .entries
        .where((e) => e.value is List)
        .any((e) => (e.value as List).isNotEmpty)) {
      throw StateError(
        'Kho đích đã có dữ liệu. Không nhập đè hoặc tự trộn dữ liệu.',
      );
    }
    final imported = source.copy();
    for (final p in imported.products) {
      target.products.add(p);
    }
    for (final entry in [
      (target.orders, imported.orders),
      (target.customers, imported.customers),
      (target.deliveries, imported.deliveries),
      (target.payroll, imported.payroll),
      (target.audit, imported.audit),
      (target.notifications, imported.notifications),
      (target.stockMoves, imported.stockMoves),
    ]) {
      for (final row in entry.$2) {
        row['id'] ??= newId();
        if (row.containsKey('actor')) {
          row['importedActor'] = row['actor'];
          row['actor'] = actor.id;
        }
        if (row.containsKey('action')) {
          row['detail'] = '[Nhập từ dữ liệu mẫu] ${row['detail']}';
        }
        entry.$1.add(row);
      }
    }
    target.log(
      actor,
      'Nhập dữ liệu cục bộ',
      'migration',
      'Nhập một lần vào kho trống, giữ nguyên dữ liệu trên thiết bị.',
    );
  });
}
