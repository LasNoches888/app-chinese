; Inno Setup script for Uchi — packages the Flutter Windows release build
; (exe + plugin DLLs + data/) into one self-contained installer exe, so
; sharing the app doesn't mean sharing a folder of files someone has to
; keep together.
#define MyAppName "Uchi"
#define MyAppVersion "0.1.0"
#define MyAppExeName "app_chinese.exe"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{9F3F0F0A-2C1E-4B7A-9C3E-4B0B8B6E5A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; One output file — this is the whole point: someone on the other end
; runs exactly one exe and never sees the DLLs/data folder underneath it.
OutputDir=..\..\build\installer
OutputBaseFilename=UchiSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
; No admin prompt — installs to the current user's own folder, since
; this is a personal build being shared directly, not a signed release
; going through a store or IT-managed rollout.
PrivilegesRequired=lowest
; Self-update (see AppUpdateService) downloads this installer and runs
; it from *inside* the running app — meaning the app's own exe and DLLs
; are locked by the very process trying to replace them. Without this,
; that install would just fail partway with a file-in-use error. Inno's
; Restart Manager integration closes the running app before copying
; files and reopens it after, the same way installing over a running
; Chrome or VS Code update prompts you to relaunch.
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
