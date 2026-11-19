#define MyAppName "Miraprint"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppExeName "miraprint.exe"

; Arca sertifikat papkasi: ilova ham aynan shu yerdan o'qiydi (CertificateService.defaultDir)
#define CertDir "{commonappdata}\MirasoftArca\cert"

[Setup]
AppId={{7F2D1A6E-4B3C-4E8A-9F1D-6C2B5A8E3D7F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=Output
OutputBaseFilename=MiraprintSetup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Sertifikatni Windows Trusted Root ro'yxatiga qo'shish uchun administrator kerak.
PrivilegesRequired=admin
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=yes

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
; Arca: 1) shu kompyuter uchun 127.0.0.1 sertifikatini yaratish (mavjud bo'lsa, qayta yaratilmaydi)
Filename: "{app}\{#MyAppExeName}"; Parameters: "--generate-cert ""{#CertDir}"""; StatusMsg: "Xavfsiz ulanish sertifikati yaratilmoqda..."; Flags: runhidden waituntilterminated
; Arca: 2) sertifikatni Windows Trusted Root ro'yxatiga o'rnatish (Chrome/Edge shunga ishonadi)
Filename: "{sys}\certutil.exe"; Parameters: "-addstore -f Root ""{#CertDir}\localhost.crt"""; StatusMsg: "Sertifikat o'rnatilmoqda..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Miraprint"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Arca sertifikatini ishonchli ro'yxatdan olib tashlash
Filename: "{sys}\certutil.exe"; Parameters: "-delstore Root ""127.0.0.1"""; Flags: runhidden; RunOnceId: "DelArcaCert"

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\MirasoftArca"
