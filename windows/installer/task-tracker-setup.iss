[Setup]
AppName=Task Tracker
AppVersion={#Version}
AppPublisher=DALI951
AppPublisherURL=https://github.com/DALI951/task-tracker
DefaultDirName={autopf}\Task Tracker
DefaultGroupName=Task Tracker
OutputDir=..\..\releases
OutputBaseFilename=Task-Tracker-v{#Version}-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\task_tracker.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Task Tracker"; Filename: "{app}\task_tracker.exe"
Name: "{autodesktop}\Task Tracker"; Filename: "{app}\task_tracker.exe"

[Run]
Filename: "{app}\task_tracker.exe"; Description: "Launch Task Tracker"; Flags: nowait postinstall skipifsilent
