; «Чистый Xiaomi» для Windows — Inno Setup 7 script.
; Build: ISCC.exe /DAppVersion=1.0.0 /DDist=..\dist /DOutDir=..\out installer\cleaner.iss
; dist\           Flutter Release folder (ChistyXiaomi.exe, flutter_windows.dll, data\) + VC++ runtime DLLs
; dist\adb\       adb.exe, AdbWinApi.dll, AdbWinUsbApi.dll, NOTICE.txt (Android SDK Platform-Tools, unmodified)
; Per-user install, no admin rights required.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef Dist
  #define Dist "..\dist"
#endif
#ifndef OutDir
  #define OutDir "..\out"
#endif

[Setup]
AppId={{B3C7E1A2-5D84-4F0B-9E26-71A4C8D90F35}
AppName=Чистый Xiaomi
AppVersion={#AppVersion}
AppVerName=Чистый Xiaomi {#AppVersion}
AppPublisher=Урдуханов Марат Закирович
AppPublisherURL=https://sessia.top
AppSupportURL=https://sessia.top
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Chisty Xiaomi
VersionInfoDescription=Chisty Xiaomi Setup
VersionInfoCompany=sessia.top
DefaultDirName={localappdata}\Programs\ChistyXiaomi
DefaultGroupName=Чистый Xiaomi
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutDir}
OutputBaseFilename=ChistyXiaomi-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ChistyXiaomi.exe
UninstallDisplayName=Чистый Xiaomi
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Ярлык на рабочем столе"; GroupDescription: "Дополнительно:"

[Files]
Source: "{#Dist}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Чистый Xiaomi"; Filename: "{app}\ChistyXiaomi.exe"
Name: "{autodesktop}\Чистый Xiaomi"; Filename: "{app}\ChistyXiaomi.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ChistyXiaomi.exe"; Description: "Запустить «Чистый Xiaomi»"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\adb\adb.exe"; Parameters: "kill-server"; Flags: runhidden waituntilterminated; RunOnceId: "KillAdb"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\adb"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  // our own adb server keeps adb.exe locked; stop it before replacing files
  if FileExists(ExpandConstant('{app}\adb\adb.exe')) then
    Exec(ExpandConstant('{app}\adb\adb.exe'), 'kill-server', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := '';
end;
