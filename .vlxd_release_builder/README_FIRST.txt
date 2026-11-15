VLXD HAI SOC - TAO SETUP MOI TU CODE HIEN TAI (WINDOWS)

MUC DICH:
- Build tren MAY CUA BAN tu D:\app\vlxd_app, bao gom toan bo patch va 204 tests ban da chay dat.
- Dong goi Windows ban moi de cai DE len ban Setup truoc.
- CHI tao file trong du an: release\, .vlxd_release_builder\.
- Khong dong cham du lieu SQLite, Firebase, AppData hoac cai dat dang co.

CACH DUNG:
1) Tai ZIP bo dong goi nay vao D:\app\vlxd_app
2) Mo PowerShell:
   cd D:\app\vlxd_app
   Expand-Archive -LiteralPath '.\VLXD_Dong_Goi_Setup_Moi.zip' -DestinationPath '.\.vlxd_release_builder' -Force
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\.vlxd_release_builder\build-update.ps1' -ProjectRoot 'D:\app\vlxd_app'
3) Xem file tai: D:\app\vlxd_app\release\installers\VLXD_Hai_Soc_Setup_<version>.exe
4) SAO LUU du lieu va dong VLXD truoc khi chay setup.

CO CHE:
- Tu dong chay flutter pub get, flutter analyze, flutter test, flutter build windows --release.
- Tao them ZIP portable chua toan bo exe/DLL/data.
- Uu tien doc file .iss CU trong D:\app\setup VLXD App (CHI DOC, khong ghi); neu khong co thi
  tim Windows uninstall Registry cua ban Inno Setup da cai de lay lai AppId.
- Neu khong tim duoc AppId cu: KHONG tao Setup de tranh sinh phan mem trung; van xuat ZIP portable.
- Neu may chua cai Inno Setup 6: van build Windows va tao file .iss de compile sau.
- Inno Setup can co san tren may neu muon tao Setup.exe.

CHU Y:
- Neu bo setup cu khong phai Inno Setup, script khong the dam bao cai de; can file .iss/setup cu.
- Neu co nhieu bo cai cu, truyen tham so -OldInstallerScript 'duong_dan_file.iss'.
- Neu muon dong goi Web nua, them -BuildWeb (CHI build ZIP, khong tu deploy Internet).
- Build chi kiem tra tests trong repo, khong thay the kiem thu cai de thuc te.
- Neu du lieu offline dang cho sync, dong bo va backup truoc khi cap nhat.
