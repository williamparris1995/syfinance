; 御财(yucai_client)Windows 安装脚本 — Inno Setup 6。
; 构建:make windows-installer(AppVersion 经 /D 从 pubspec 注入,勿手改)。
; 形态(grill 2026-08-29):per-user 免管理员安装 + 中文向导 + 免签名
; (SmartScreen 警告为已知代价,自用优先)。

#define public AppName "御财"
#define public AppExeName "yucai_client.exe"
#ifndef AppVersion
#define public AppVersion "0.0.0"
#endif

[Setup]
AppId={{5a7d9db0-7864-4b0a-8477-be651e5b6a49}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=YuCai
DefaultDirName={localappdata}\Programs\yucai
DefaultGroupName=御财
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=yucai-setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\御财"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载御财"; Filename: "{uninstallexe}"
Name: "{autodesktop}\御财"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即启动御财"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; 清理 app 运行时注册的开机自启(R7-B FR-3;launch_at_startup 写 HKCU Run/yucai_client)。
Filename: "reg.exe"; Parameters: "delete HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v yucai_client /f"; Flags: runhidden; RunOnceId: "RemoveAutostup"
