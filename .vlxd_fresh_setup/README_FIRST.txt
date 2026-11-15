VLXD APP - SUA LOI NHAN DIEN INNO SETUP (THANG 11/2026)
=================================================
Ung dung chung: vlxd_app; hai cua hang: Bay Hai va Hai Soc.

LOI DA SUA: winget bao Inno Setup da duoc cai nhung script cu chi tim Inno Setup 6.
Ban nay tu tim ISCC.exe trong Inno Setup 6, 7 hoac phien ban moi, trong Program Files,
LocalAppData, PATH, registry va thu muc quan ly winget.

CACH DUNG:
1) Dat ZIP vao D:\app\vlxd_app
2) PowerShell:
   cd D:\app\vlxd_app
   Expand-Archive -LiteralPath .\VLXD_App_Setup_Sua_Nhan_Dien_Inno.zip -DestinationPath .\.vlxd_fresh_setup -Force
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_fresh_setup\build-fresh.ps1 -ProjectRoot D:\app\vlxd_app
3) Neu may co ISCC.exe nhung khong tu tim duoc, chay lai va them:
   -InnoCompiler 'DUONG_DAN_DAY_DU_DEN_ISCC.exe'
4) Khi thanh cong, bo cai o:
   D:\app\vlxd_app\release\installers\VLXD_App_Setup_1.0.1.exe

QUAN TRONG:
- Khong go ban cu truoc khi tao duoc Setup.exe va sao luu/sync du lieu.
- Build khong tu dong go cai hay sua SQLite/Firebase/Web.
- Installer moi AppId=VLXD.App.Windows.Desktop. Khong tu dong nhan AppId cu.
- Uninstall app cu co the anh huong du lieu local, can backup truoc.
- Neu build/test that bai, dung va gui log; khong co installer hop le.
