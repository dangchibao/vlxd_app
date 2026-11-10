part of 'app.dart';

class FirebaseGate extends StatelessWidget {
  const FirebaseGate({super.key});
  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (shop) => GetBuilder<SessionController>(
      builder: (session) {
        if (session.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session.mustChangePassword) {
          return const PasswordPage(requiredChange: true);
        }
        if (shop.actor != null) {
          if (shop.syncing) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tải dữ liệu cửa hàng…'),
                  ],
                ),
              ),
            );
          }
          if (shop.syncError != null && !shop.showingOfflineSnapshot) {
            return Scaffold(
              appBar: AppBar(title: const Text('Kết nối cửa hàng')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(shop.syncError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => shop.connect(shop.actor!),
                        child: const Text('Thử đồng bộ lại'),
                      ),
                      TextButton(
                        onPressed: session.signOut,
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const ShopShell();
        }
        return const FirebaseLoginPage();
      },
    ),
  );
}

class FirebaseLoginPage extends StatefulWidget {
  const FirebaseLoginPage({super.key});
  @override
  State<FirebaseLoginPage> createState() => _FirebaseLoginPageState();
}

class _FirebaseLoginPageState extends State<FirebaseLoginPage> {
  final account = TextEditingController(), password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    account.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: panel(
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.roofing_rounded, color: blue, size: 56),
                      const SizedBox(height: 16),
                      titleText('VLXD Bảy Hải', size: 30),
                      hint('Gò Dầu • Tây Ninh'),
                      const SizedBox(height: 28),
                      titleText('Đăng nhập', size: 24),
                      const SizedBox(height: 16),
                      TextField(
                        controller: account,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Tài khoản / SĐT / Email',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) =>
                            session.signIn(account.text, password.text),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          suffixIcon: IconButton(
                            tooltip: 'Ẩn / hiện mật khẩu',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (session.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            session.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      FilledButton(
                        onPressed: session.loading
                            ? null
                            : () => session.signIn(account.text, password.text),
                        child: const Text('Đăng nhập'),
                      ),
                      TextButton(
                        onPressed: () => safeDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Quên mật khẩu'),
                            content: const Text(
                              'Liên hệ chủ cửa hàng để được đặt mật khẩu tạm. Không gửi SMS hoặc email khôi phục.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Đã hiểu'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Quên mật khẩu?'),
                      ),
                      hint(
                        'Chỉ tài khoản được chủ cấp quyền mới truy cập dữ liệu. Không có đăng ký tự do hoặc mật khẩu mặc định.',
                      ),
                      if (session.auth.currentUser != null)
                        TextButton(
                          onPressed: session.signOut,
                          child: const Text('Đăng xuất tài khoản hiện tại'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordPage extends StatefulWidget {
  final bool requiredChange;
  const PasswordPage({this.requiredChange = false, super.key});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final current = TextEditingController(),
      next = TextEditingController(),
      repeat = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.requiredChange ? 'Đổi mật khẩu tạm' : 'Đổi mật khẩu của tôi',
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.requiredChange)
                  const Text('Bạn cần đổi mật khẩu trước khi vào cửa hàng.'),
                const SizedBox(height: 16),
                for (final entry in [
                  (current, 'Mật khẩu hiện tại'),
                  (next, 'Mật khẩu mới • ít nhất 10 ký tự'),
                  (repeat, 'Nhập lại mật khẩu mới'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: entry.$1,
                      obscureText: true,
                      decoration: InputDecoration(labelText: entry.$2),
                    ),
                  ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () => attempt(() async {
                          if (next.text != repeat.text) {
                            throw ArgumentError('Hai mật khẩu mới không khớp.');
                          }
                          setState(() => saving = true);
                          try {
                            await Get.find<SessionController>().changePassword(
                              current.text,
                              next.text,
                            );
                            if (!widget.requiredChange && context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        }),
                  child: const Text('Lưu mật khẩu mới'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : Get.find<SessionController>().signOut,
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
