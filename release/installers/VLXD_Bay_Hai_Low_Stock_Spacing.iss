[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD Bay Hai
AppVersion=1.0.10
AppVerName=VLXD Bay Hai 1.0.10
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD Bay Hai
UsePreviousAppDir=yes
PrivilegesRequired=lowest
OutputDir=D:\app\vlxd_app\release\installers
OutputBaseFilename=VLXD_Bay_Hai_Setup_1.0.10
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\vlxd_app.exe

[Files]
Source: "D:\app\vlxd_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"