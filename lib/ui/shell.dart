part of 'app.dart';

// Presentation order is independent of page IDs used by existing shortcuts.
const _navigationOrder = [0, 1, 2, 3, 4, 5, 6, 9, 7, 8];

class ShopShell extends StatelessWidget {
  const ShopShell({super.key});

  void _logout(ShopController c) {
    if (Get.isRegistered<SessionController>()) {
      attempt(() => Get.find<SessionController>().signOut());
    } else {
      c.logout();
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (c) => LayoutBuilder(
      builder: (context, box) {
        final desktop = box.maxWidth >= 1000;
        // New page widgets must receive controller updates. Reusing const
        // instances here skips rebuilding stateless catalogs after a save.
        // A stable key keeps forms/filters alive while the same page is open.
        final pageKey = ValueKey(c.page);
        final pages = <Widget>[
          DashboardPage(key: pageKey),
          ProductsPage(key: pageKey),
          SalesPage(key: pageKey),
          InventoryPage(key: pageKey),
          DeliveriesPage(key: pageKey),
          DebtPage(key: pageKey),
          ReportsPage(key: pageKey),
          AuditPage(key: pageKey),
          SettingsPage(key: pageKey),
          InvoicesPage(key: pageKey),
        ];
        final navigation = ListView(
          children: [
            const Padding(padding: EdgeInsets.all(24), child: _ShopBrand()),
            for (final i in _navigationOrder)
              ListTile(
                selected: c.page == i,
                selectedColor: blue,
                leading: Icon(navIcons[i]),
                title: Text(destinations[i]),
                onTap: () {
                  c.navigate(i);
                  Navigator.pop(context);
                },
              ),
          ],
        );
        final warning =
            !c.isLive ||
            c.syncError != null ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: !desktop,
            titleSpacing: desktop ? 16 : null,
            title: desktop
                ? Row(
                    children: [
                      const _ShopBrand(light: true),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final i in _navigationOrder)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => c.navigate(i),
                                      icon: Icon(navIcons[i], size: 20),
                                      label: Text(destinations[i]),
                                      style: TextButton.styleFrom(
                                        foregroundColor: c.page == i
                                            ? blue
                                            : Colors.white,
                                        backgroundColor: c.page == i
                                            ? Colors.white
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Bảy Hải • ${destinations[c.page]}',
                    style: const TextStyle(fontSize: 17),
                  ),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: c.busy ? null : () => _logout(c),
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
            toolbarHeight: desktop ? 70 : 56,
          ),
          drawer: desktop ? null : Drawer(child: navigation),
          body: Row(
            children: [
              if (desktop)
                Container(
                  width: 196,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Color(0xFFDCE4EE))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 154,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE2ECF7), Color(0xFFF7F3EA)],
                          ),
                        ),
                        child: const Icon(
                          Icons.layers_outlined,
                          size: 76,
                          color: Color(0xFF8199B5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: hint('QUẢN LÝ CỬA HÀNG'),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4EFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(navIcons[c.page], color: blue, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                destinations[c.page],
                                style: const TextStyle(
                                  color: blue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: blue,
                              size: 30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.actor!.role == Role.owner
                                  ? 'Chủ cửa hàng'
                                  : 'Nhân viên bán hàng',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  c.syncError != null
                                      ? Icons.cloud_off_outlined
                                      : Icons.cloud_done_outlined,
                                  size: 16,
                                  color: c.syncError != null
                                      ? Colors.orange
                                      : const Color(0xFF168366),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: hint(
                                    !c.isLive
                                        ? 'Bản dùng thử'
                                        : c.syncing
                                        ? 'Đang đồng bộ'
                                        : c.syncError != null
                                        ? 'Lỗi đồng bộ'
                                        : 'Đã kết nối',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (warning)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF3DC),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          !c.isLive
                              ? 'DỮ LIỆU MẪU • Lưu trên thiết bị này'
                              : c.syncError != null
                              ? c.syncError!
                              : 'Windows Firebase đang thử nghiệm • Sử dụng bản Web khi vận hành',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF885C13),
                          ),
                        ),
                      ),
                    if (c.busy || c.syncing)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(child: pages[c.page]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ShopBrand extends StatelessWidget {
  final bool light;
  const _ShopBrand({this.light = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.layers, size: 36, color: light ? Colors.white : blue),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VLXD Bảy Hải',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : ink,
            ),
          ),
          Text(
            'Gò Dầu • Tây Ninh',
            style: TextStyle(
              fontSize: 12,
              color: light ? Colors.white : const Color(0xFF657993),
            ),
          ),
        ],
      ),
    ],
  );
}
