; Script Inno Setup untuk Syupeo Desktop Edition
; Dilengkapi bundle otomatis Driver Printer Thermal Kasir (POS-58 / POS-80)

#define MyAppName "Syupeo"
#define MyAppVersion "1.0.15"
#define MyAppPublisher "Mudahkan.online"
#define MyAppURL "https://pos.mudahkan.online"
#define MyAppExeName "Syupeo.exe"

[Setup]
AppId={{5E3B87A2-7E19-4F8A-98C3-A89E6290C041}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=ManggaPOS_Setup_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di Desktop"; GroupDescription: "Ikon Tambahan:"
Name: "installprinterdriver"; Description: "Pasang Driver Printer Thermal Kasir (POS-58 & POS-80 USB)"; GroupDescription: "Perangkat Keras Kasir (Disarankan):"; Flags: unchecked

[Files]
; Seluruh file biner rilis aplikasi Syupeo
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "dpos.exe"
Source: "..\build\windows\x64\runner\Release\dpos.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion
; Paket Driver Printer Thermal
Source: "drivers\*"; DestDir: "{app}\drivers"; Flags: ignoreversion recursesubdirs createallsubdirs
; Buku Panduan Pengguna Windows
Source: "..\PANDUAN_WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\{#MyAppName}\Buku Panduan Pengguna Windows"; Filename: "{app}\PANDUAN_WINDOWS.md"
Name: "{autoprograms}\{#MyAppName}\Driver Printer Thermal (POS-58 & 80)"; Filename: "{app}\drivers\POSPrinterDriverSetup.exe"
Name: "{autoprograms}\{#MyAppName}\Panduan Driver Printer Thermal"; Filename: "{app}\drivers\PANDUAN_DRIVER_PRINTER.txt"
Name: "{autoprograms}\{#MyAppName}\Uninstall Syupeo"; Filename: "{uninstallexe}"

[Run]
; Jalankan instalasi driver printer jika dicentang oleh user
Filename: "{app}\drivers\POSPrinterDriverSetup.exe"; Description: "Pasang Driver Printer Thermal (POS-58 & POS-80 USB)"; Flags: postinstall skipifsilent nowait; Tasks: installprinterdriver
; Jalankan aplikasi Syupeo setelah instalasi selesai
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan {#MyAppName}"; Flags: nowait postinstall skipifsilent
