VLXD Bay Hai - Mobile Web/PWA + Android APK V5

1) Apply UI patch (15 modifications to mobile_products.dart and debt.dart):
  cd D:\app\vlxd_app
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<folder>\01_CAI_UI_MOBILE_PS51.ps1"
  IMPORTANT: If SOURCE-MISMATCH, stop. Never force.

2) For Web/PWA PREVIEW only:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<folder>\02_BUILD_VA_XEM_TRUOC.ps1"

3) For Android APK (after successfully applying UI patch):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<folder>\03_BUILD_ANDROID_APK_PS51.ps1"

  Requirements: Flutter SDK, Android SDK, JDK compatible with Flutter/Gradle, internet for initial dependencies, android/app/google-services.json matching applicationId vn.bayhai.vlxd_app. Never copy a config for a different Firebase project.
  Output: D:\app\vlxd_app\.vlxd_android_apk_outputs\VLXD_Bay_Hai_Android_TEST_<date>.apk

  Source snapshot Android Gradle release signingConfig uses debug signing key. Treat generated APK as INTERNAL TEST ONLY; set up stable private release signing before rolling out publicly or installing updates across devices. Do not ship/disclose keystore, passwords or google-services.json in support ZIP.

  WARNING: Android app and browser PWA may have DIFFERENT local offline storage. Firebase sync is shared after login only if configured, authorized and functioning. Do not uninstall the existing Android app or wipe local data without verifying sync/backup. This ZIP does not install or publish anything automatically and does not alter Android project signing.
