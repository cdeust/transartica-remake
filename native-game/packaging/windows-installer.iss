; SPDX-License-Identifier: MIT
; Source: https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm
; Build with ISCC /DPayload=... /DOutput=... /DBuildVersion=... this-file.iss
#ifndef Payload
  #error Payload is required
#endif
#ifndef Output
  #error Output is required
#endif
#ifndef BuildVersion
  #error BuildVersion is required
#endif

[Setup]
AppId=Transartica.Native
AppName=Transartica
AppVersion={#BuildVersion}
AppPublisher=Transartica remake contributors
DefaultDirName={localappdata}\Programs\Transartica
DefaultGroupName=Transartica
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Output}
OutputBaseFilename=Transartica-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\Transartica.exe
CloseApplications=no
RestartApplications=no

[Files]
Source: "{#Payload}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Transartica"; Filename: "{app}\Transartica.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Transartica.exe"; Description: "Launch Transartica"; Flags: nowait postinstall skipifsilent
