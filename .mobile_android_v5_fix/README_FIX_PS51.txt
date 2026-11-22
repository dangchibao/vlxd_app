VLXD Bay Hai - MOBILE/PWA/ANDROID V5 - FIX PowerShell 5.1

Nguyen nhan loi lan truoc: Windows PowerShell 5.1 coi mang JSON 15 muc nhu 1 object, ghep nhan/pattern va bao SOURCE-MISMATCH count=0.

V5 FIX chi sua script doc mang JSON, GIU NGUYEN 15 thay doi UI trong edits.json, va script build APK/Web.
Da doi chieu lan luot 15 pattern tren 2 file mobile_products.dart, debt.dart cua ban UI V3 theo ma nguon thuc, moi pattern khop 1 lan. Chua chay flutter truc tiep tren may nguoi dung.

CAI:
  cd D:\app\vlxd_app
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<thu_muc_giai_nen>\01_CAI_UI_MOBILE_PS51.ps1"

Sau khi '[SUCCESS]' va flutter analyze/test dat:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<thu_muc_giai_nen>\02_BUILD_VA_XEM_TRUOC.ps1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<thu_muc_giai_nen>\03_BUILD_ANDROID_APK_PS51.ps1"

Khong tu deploy LIVE, khong tu cai APK, khong xoa du lieu. Android Release dang duoc ky bang debug key nen chi test noi bo. Can kiem tra Firebase Android va du lieu offline truoc khi cai de.
