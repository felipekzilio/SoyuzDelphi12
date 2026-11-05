unit uVanguard;
interface
uses System.SysUtils;
type
  TVanguard = class
  private
    function ReadUninstallCommand: string;
    function RunAndWait(const CommandLine: string; TimeoutMs: Cardinal): Boolean;
    function RemoveServicesFallback: Boolean;
  public
    /// Para os servicos vgc e vgk (vgk normalmente so para apos reiniciar).
    procedure Stop;
    /// Desinstala o Riot Vanguard usando o desinstalador oficial registrado
    /// no Windows. Se ele nao for encontrado, remove os servicos vgc/vgk.
    /// Retorna True se a remocao foi concluida (pode exigir reinicializacao).
    function Uninstall: Boolean;
  end;
implementation
uses Winapi.Windows, System.Win.Registry, uServiceControl, uLogger;

const
  UninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Riot Vanguard';

procedure TVanguard.Stop;
var Svc: TServiceControl;
begin
  Svc := TServiceControl.Create;
  try
    Svc.StopService('vgc');
    if not Svc.StopService('vgk', 5000) then
      TLogger.Info('O driver vgk costuma permanecer ativo ate reiniciar o Windows.');
  finally Svc.Free; end;
end;

function TVanguard.ReadUninstallCommand: string;
var Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(UninstallKey) then
    try
      if Reg.ValueExists('QuietUninstallString') then
        Result := Trim(Reg.ReadString('QuietUninstallString'));
      if (Result = '') and Reg.ValueExists('UninstallString') then
        Result := Trim(Reg.ReadString('UninstallString'));
    finally
      Reg.CloseKey;
    end;
  finally Reg.Free; end;
end;

function TVanguard.RunAndWait(const CommandLine: string; TimeoutMs: Cardinal): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
  ExitCodeValue: DWORD;
begin
  Result := False;
  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);
  SI.cb := SizeOf(SI);
  Cmd := CommandLine;
  UniqueString(Cmd);
  if not CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil, nil, SI, PI) then
  begin
    TLogger.Warning('Falha ao iniciar o desinstalador: ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    if WaitForSingleObject(PI.hProcess, TimeoutMs) <> WAIT_OBJECT_0 then
    begin
      TLogger.Warning('Tempo esgotado aguardando o desinstalador do Vanguard.');
      Exit;
    end;
    if GetExitCodeProcess(PI.hProcess, ExitCodeValue) then
    begin
      Result := ExitCodeValue = 0;
      if not Result then
        TLogger.Warning(Format('Desinstalador terminou com codigo %d.', [ExitCodeValue]));
    end;
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
end;

function TVanguard.RemoveServicesFallback: Boolean;
var Svc: TServiceControl; OkVgc, OkVgk: Boolean;
begin
  TLogger.Info('Removendo servicos do Vanguard (vgc, vgk)...');
  Svc := TServiceControl.Create;
  try
    OkVgc := Svc.DeleteService('vgc');
    OkVgk := Svc.DeleteService('vgk');
    Result := OkVgc and OkVgk;
  finally Svc.Free; end;
end;

function TVanguard.Uninstall: Boolean;
var Cmd: string;
begin
  Cmd := ReadUninstallCommand;
  if Cmd <> '' then
  begin
    TLogger.Info('Executando desinstalador do Vanguard: ' + Cmd);
    Result := RunAndWait(Cmd, 120000);
    if Result then
    begin
      TLogger.Info('Vanguard desinstalado. Reinicie o Windows para concluir.');
      Exit;
    end;
    TLogger.Warning('Desinstalador oficial falhou; tentando remover os servicos.');
  end
  else
    TLogger.Warning('Desinstalador do Vanguard nao registrado; removendo os servicos.');

  Result := RemoveServicesFallback;
  if Result then
    TLogger.Info('Servicos do Vanguard marcados para remocao. Reinicie o Windows para concluir.');
end;
end.
