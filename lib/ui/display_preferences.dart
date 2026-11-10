import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local presentation preferences only: no business or Firebase data is changed.
/// Each device stores its own selection.
enum VlxdFontSize { normal, large, extraLarge }

class VlxdDisplayPreferences extends ChangeNotifier {
  VlxdDisplayPreferences._();

  static final VlxdDisplayPreferences instance = VlxdDisplayPreferences._();

  static const _fontKey = 'vlxd.display.font.v1';
  static const _buttonsKey = 'vlxd.display.large_buttons.v1';
  static const _densityKey = 'vlxd.display.comfortable_density.v1';

  VlxdFontSize _fontSize = VlxdFontSize.normal;
  bool _largeButtons = false;
  bool _comfortableDensity = false;
  bool _loaded = false;

  VlxdFontSize get fontSize => _fontSize;
  bool get largeButtons => _largeButtons;
  bool get comfortableDensity => _comfortableDensity;
  bool get loaded => _loaded;

  double get fontFactor => switch (_fontSize) {
        VlxdFontSize.normal => 1.0,
        VlxdFontSize.large => 1.25,
        VlxdFontSize.extraLarge => 1.45,
      };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_fontKey);
      _fontSize = VlxdFontSize.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => VlxdFontSize.normal,
      );
      _largeButtons = prefs.getBool(_buttonsKey) ?? false;
      _comfortableDensity = prefs.getBool(_densityKey) ?? false;
    } catch (_) {
      // Keep safe defaults when persistent storage is unavailable.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setFontSize(VlxdFontSize value) async {
    if (_fontSize == value) return;
    _fontSize = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontKey, value.name);
    } catch (_) {
      // Settings still take effect for this session.
    }
  }

  Future<void> setLargeButtons(bool value) async {
    if (_largeButtons == value) return;
    _largeButtons = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_buttonsKey, value);
    } catch (_) {}
  }

  Future<void> setComfortableDensity(bool value) async {
    if (_comfortableDensity == value) return;
    _comfortableDensity = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_densityKey, value);
    } catch (_) {}
  }

  ThemeData applyTheme(ThemeData base) {
    final buttonHeight = _largeButtons ? 56.0 : 44.0;
    final iconHeight = _largeButtons ? 52.0 : 40.0;
    final verticalPadding = _comfortableDensity ? 18.0 : 12.0;
    final buttonMinimum = Size(40, buttonHeight);
    return base.copyWith(
      visualDensity: _comfortableDensity
          ? VisualDensity.standard
          : VisualDensity.compact,
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          minimumSize: WidgetStatePropertyAll(buttonMinimum),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          minimumSize: WidgetStatePropertyAll(buttonMinimum),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          minimumSize: WidgetStatePropertyAll(buttonMinimum),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: base.iconButtonTheme.style?.copyWith(
          minimumSize: WidgetStatePropertyAll(Size(iconHeight, iconHeight)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: !_comfortableDensity,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: verticalPadding,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        dense: !_comfortableDensity,
      ),
    );
  }
}

/// This is intentionally a standalone widget: can be inserted in SettingsPage
/// without changing its other business controls or navigation.
class VlxdDisplayPreferencesPanel extends StatelessWidget {
  const VlxdDisplayPreferencesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = VlxdDisplayPreferences.instance;
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hiển thị và dễ thao tác',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Áp dụng cho thiết bị này. Chọn cỡ chữ rõ hơn, nút lớn hơn '
                'hoặc giao diện thoáng hơn.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Cỡ chữ', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in VlxdFontSize.values)
                    ChoiceChip(
                      label: Text(switch (option) {
                        VlxdFontSize.normal => 'Thường',
                        VlxdFontSize.large => 'Lớn (125%)',
                        VlxdFontSize.extraLarge => 'Rất lớn (145%)',
                      }),
                      selected: prefs.fontSize == option,
                      onSelected: (selected) {
                        if (selected) prefs.setFontSize(option);
                      },
                    ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nút lớn, dễ bấm'),
                subtitle: const Text('Phóng to các nút thao tác chính'),
                value: prefs.largeButtons,
                onChanged: prefs.setLargeButtons,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Giao diện thoáng'),
                subtitle: const Text('Tăng khoảng cách ô nhập và danh sách'),
                value: prefs.comfortableDensity,
                onChanged: prefs.setComfortableDensity,
              ),
              const SizedBox(height: 8),
              Text(
                'Mặc định: chữ Thường, nút chuẩn, giao diện Gọn. '
                'Cỡ chữ rất lớn có thể cần cuộn thêm trên điện thoại nhỏ.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
