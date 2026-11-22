VLXD Bay Hai Mobile / Web PWA / Android - V7

V6 stopped at flutter analyze: 14 unnecessary_const lint messages (2 each in seven const PopupMenuItem widgets).
V7 removes exactly those 14 redundant nested `const` keywords from seven generated menu fragments.
It does not suppress analysis and does not change app logic, Firebase, storage, or Android signing.
The installer prechecks 15 matches, saves original two UI files, runs dart format, flutter analyze, flutter test, and rolls back if any fails.
After successful install run the included Android APK build and Web/PWA preview scripts separately.
Avoid publishing to live until reviewing the preview on a real phone.
