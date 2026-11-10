import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlxd_app/ui/display_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Default display preferences are compact and normal', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = VlxdDisplayPreferences.instance;
    await prefs.load();
    expect(prefs.fontSize, VlxdFontSize.normal);
    expect(prefs.fontFactor, 1.0);
    expect(prefs.largeButtons, isFalse);
    expect(prefs.comfortableDensity, isFalse);
  });

  test('Font preference is stored on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = VlxdDisplayPreferences.instance;
    await prefs.load();
    await prefs.setFontSize(VlxdFontSize.extraLarge);
    expect(prefs.fontFactor, 1.45);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('vlxd.display.font.v1'), 'extraLarge');
  });

  test('Button and density preferences are persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = VlxdDisplayPreferences.instance;
    await prefs.load();
    await prefs.setLargeButtons(true);
    await prefs.setComfortableDensity(true);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool('vlxd.display.large_buttons.v1'), true);
    expect(stored.getBool('vlxd.display.comfortable_density.v1'), true);
  });
}
