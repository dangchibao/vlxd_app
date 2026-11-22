VLXD APP - COMPLETE WINDOWS + WEB/PWA RELEASE PACKAGE
Version: 1.0.3 (example; may be changed via -Version)
======================================================

ABOUT
- Builds & packages the CURRENT local D:\app\vlxd_app source.
- Windows: Inno Setup installer, same AppId as VLXD App 1.0.1 / 1.0.2.
- Web: responsive browser + installable PWA for iPhone / Android / laptop.
- Optional: Android APK.
- No native iOS IPA is produced on Windows.
- All code paths in lib/ stay untouched; no changes to Firebase rules.
- Does not uninstall or install Windows software automatically.

IMPORTANT SAFETY
Before deploying to a real website, review ALL unsynced / failed / uncertain
transactions on each desktop, Android and Web/PWA device. The app's existing
Web build enables PRODUCTION automatic outbox sync, so a new deployment can
start processing pending orders. Make sure local SQLite/IndexedDB queues are
accounted for and backups exist. NEVER clear browser site data before that.

The project's .firebaserc default is NOT vlxd-bay-hai. These scripts always
pass '--project vlxd-bay-hai' to avoid deploying the wrong project.

STEP 1: DOWNLOAD, EXTRACT, OPEN POWERSHELL
  cd D:\app\vlxd_app
  Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\VLXD_Release_Windows_Web_PWA_20261118.zip" -DestinationPath .\.vlxd_release_all -Force

STEP 2: BUILD WINDOWS + PWA (NO WEBSITE DEPLOY)
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_release_all\build-and-release.ps1 -ProjectRoot D:\app\vlxd_app -Version 1.0.3 -BuildNumber 4

OPTION: ALSO BUILD ANDROID APK
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_release_all\build-and-release.ps1 -ProjectRoot D:\app\vlxd_app -Version 1.0.3 -BuildNumber 4 -BuildAndroidApk

STEP 3: IF/ONLY IF ALL OFFLINE QUEUES WERE REVIEWED, DEPLOY WEB
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_release_all\deploy-hosting-after-review.ps1 -ProjectRoot D:\app\vlxd_app -IReviewedAllDeviceQueues

ALTERNATIVE: BUILD + DEPLOY IN ONE GO, ONLY AFTER REVIEWING QUEUES
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_release_all\build-and-release.ps1 -ProjectRoot D:\app\vlxd_app -Version 1.0.3 -BuildNumber 4 -DeployHosting -IReviewedAllDeviceQueues

OUTPUTS (AFTER SUCCESSFUL RUN)
  D:\app\vlxd_app\release\installers\VLXD_App_Setup_1.0.3.exe
  D:\app\vlxd_app\release\packages\VLXD_Web_PWA_1.0.3.zip
  D:\app\vlxd_app\release\packages\VLXD_All_Platforms_1.0.3.zip
  D:\app\vlxd_app\release\packages\VLXD_Release_1.0.3.txt
  Optional APK: release\packages\VLXD_Android_1.0.3.apk

WINDOWS INSTALL
- Review offline operations, back up your local databases, close VLXD App.
- Run Setup_1.0.3.exe and keep existing install folder.
- Old AppId is preserved: VLXD.App.Windows.Desktop.

WEB / IPHONE / ANDROID PWA
- https://vlxd-bay-hai.web.app/
- Laptop: open site in browser.
- iPhone: Safari > Share > Add to Home Screen.
- Android: Chrome > menu > Install app / Add to Home screen.
- On update, close/relaunch the PWA; never clear storage while unsynced.

If Flutter test fails, no Windows/Web build or deployment will start.
The scripts must run on your Windows development PC with Flutter, Inno Setup
and Firebase CLI installed. This ZIP is a release tool, NOT pre-built binaries.
