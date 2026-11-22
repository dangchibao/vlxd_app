VLXD Bay Hai V8: Fix popup menu render overflow and outdated UI test.

After V7: Flutter analyze passed; menu Row overflowed 6.2 px and V3 test expected an obsolete long label. Installer rolled back.
V8 wraps text in Flexible with ellipsis for all 8 product popup menu items. Preserves menu action values and callbacks.
V8 also updates the two 'find.text' lookups in test/ui_responsive_real_source_v3_test.dart from the old verbose label to 'Chi tiết'.
The actual details dialog and overflow assertions remain tested. No test disabled.
Installer backs up both UI files AND the test, formats/analyzes/tests, rolls back all 3 on failure.
No Firebase deployment, Android install, DB changes or signing key updates.
Build Web/PWA/Android APK only after success. APK is for internal tests with debug signing.
