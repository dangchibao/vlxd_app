[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD Bay Hai
AppVersion=1.0.8
AppVerName=VLXD Bay Hai 1.0.8
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD Bay Hai
OutputDir=D:\app\vlxd_app\release\installers
OutputBaseFilename=VLXD_Bay_Hai_Setup_1.0.8
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UsePreviousGroup=no
CloseApplications=yes
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vlxd_app.exe
DisableProgramGroupPage=yes

[Files]
Source: "D:\app\vlxd_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{autoprograms}\VLXD App.lnk"
Type: files; Name: "{autodesktop}\VLXD App.lnk"

[Icons]
Name: "{autoprograms}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\vlxd_app.exe"; Description: "Launch VLXD Bay Hai"; Flags: nowait postinstall skipifsilent