[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD App
AppVersion=1.0.1
AppVerName=VLXD App 1.0.1
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD App
OutputDir=D:\app\vlxd_app\release\installers
OutputBaseFilename=VLXD_App_Setup_1.0.1
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UsePreviousGroup=yes
CloseApplications=yes
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vlxd_app.exe
DisableDirPage=no
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Tao loi tat tren Desktop"; Flags: unchecked

[Files]
Source: "D:\app\vlxd_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VLXD App"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD App"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\vlxd_app.exe"; Description: "Mo VLXD App"; Flags: nowait postinstall skipifsilent