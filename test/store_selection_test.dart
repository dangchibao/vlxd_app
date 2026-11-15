// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/controllers/session_controller.dart';
import 'package:vlxd_app/data/store_profile.dart';
import 'package:vlxd_app/ui/store_selection.dart';

void main() {
  test('account aliases and profile paths are store scoped', () {
    expect(
      loginEmail('lan', storeId: 'hai-soc'),
      'lan@accounts.haisoc.invalid',
    );
    expect(loginEmail('lan'), 'lan@accounts.bayhai.invalid');
    expect(loginEmail('admin', storeId: 'hai-soc'), loginEmail('admin'));
    expect(
      loginEmail('dangchibao2001@gmail.com', storeId: 'hai-soc'),
      'dangchibao2001@gmail.com',
    );
    expect(StoreProfile.profilesPath('hai-soc'), 'stores/hai-soc/members');
    expect(StoreProfile.profilesPath('bay-hai'), 'users');
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('both stores can be selected at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      StoreProfile? selected;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: StoreSelectionPage(
            key: UniqueKey(),
            onSelected: (store) async {
              selected = store;
            },
          ),
        ),
      );
      await show();
      await tester.tap(find.text('Cửa hàng Hai Sóc'));
      expect(selected, StoreProfile.haiSoc);
      await show();
      await tester.tap(find.text('Cửa hàng Bảy Hải'));
      expect(selected, StoreProfile.bayHai);
      expect(tester.takeException(), isNull);
    });
  }
}
