part of 'app.dart';

// Presentation order is independent of page IDs used by existing shortcuts.
const _navigationOrder = [0, 1, 2, 3, 4, 5, 6, 9, 10, 7, 8];

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
          AccountingPage(key: pageKey),
        ];
        final navigation = ListView(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: _ShopBrand()),
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
        final warning = !c.isLive || c.syncError != null;
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
                      const SizedBox(width: 12),
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
                                          horizontal: 10,
                                          vertical: 11,
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
            toolbarHeight: desktop ? 58 : 54,
          ),
          bottomNavigationBar: desktop
              ? null
              : SafeArea(
                  top: false,
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          for (final i in [0, 1, 2, 3])
                            Expanded(
                              child: InkWell(
                                key: ValueKey('mobile-nav-$i'),
                                onTap: () => c.navigate(i),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      navIcons[i],
                                      size: 22,
                                      color: c.page == i
                                          ? blue
                                          : const Color(0xFF657993),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      destinations[i],
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: c.page == i
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: c.page == i
                                            ? blue
                                            : const Color(0xFF657993),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            child: Builder(
                              builder: (inner) => InkWell(
                                onTap: () => Scaffold.of(inner).openDrawer(),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.menu, size: 22),
                                    SizedBox(height: 3),
                                    Text(
                                      'Thêm',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          drawer: desktop ? null : Drawer(child: navigation),
          body: Row(
            children: [
              // Desktop already has full navigation in the blue header.
              // Remove redundant 196px sidebar and its blank branding panel.
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
                              ? '${c.syncError!}${c.snapshotAt == null ? '' : ' • Dữ liệu lúc ${DateFormat('dd/MM HH:mm').format(c.snapshotAt!)}'}'
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
