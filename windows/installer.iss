#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{8F1B4A7E-3C52-4E9B-9D64-QXTHEATER001}
AppName=亲选小剧场
AppVersion={#AppVersion}
AppPublisher=Lubob
DefaultDirName={autopf}\QinxuanTheater
DefaultGroupName=亲选小剧场
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=qinxuan-theater-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\亲选小剧场"; Filename: "{app}\bilibili_kid_viewer.exe"
Name: "{autodesktop}\亲选小剧场"; Filename: "{app}\bilibili_kid_viewer.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\bilibili_kid_viewer.exe"; Description: "{cm:LaunchProgram,亲选小剧场}"; Flags: nowait postinstall skipifsilent
