unit uServiceControl;
interface
uses System.SysUtils;
type
  TServiceControl = class
  public
    /// Para um servico do Windows e aguarda ate ele ficar parado.
    /// Retorna True se o servico estiver parado ao final (ou ja estava).
    /// Requer privilegios de administrador.
    function StopService(const ServiceName: string; TimeoutMs: Cardinal = 15000): Boolean;
    /// Marca um servico para remocao (efetiva apos parar ou reiniciar).
    function DeleteService(const ServiceName: string): Boolean;
    /// Registra um servico VGC local quando ele nao existe.
    function InstallVgcService(const ServiceName: string = 'vgc';
      const ServiceExe: string = ''; const DisplayName: string = 'Riot Vanguard Service'): Boolean;
    /// Inicia um servico no caso de ja existir e nao estar em execucao.
    function StartServiceIfNeeded(const ServiceName: string; TimeoutMs: Cardinal = 15000): Boolean;
  end;
implementation
uses Winapi.Windows, Winapi.WinSvc, System.IOUtils, uLogger;

function TServiceControl.StopService(const ServiceName: string; TimeoutMs: Cardinal): Boolean;
var
  SCM, Svc: SC_HANDLE;
  Status: TServiceStatus;
  StartedAt: UInt64;
  Err: DWORD;
begin
  Result := False;
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then
  begin
    TLogger.Warning('Nao foi possivel abrir o Service Control Manager: ' +
      SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    Svc := OpenService(SCM, PChar(ServiceName), SERVICE_STOP or SERVICE_QUERY_STATUS);
    if Svc = 0 then
    begin
      Err := GetLastError;
      case Err of
        ERROR_SERVICE_DOES_NOT_EXIST:
          TLogger.Warning(Format('Servico %s nao existe.', [ServiceName]));
        ERROR_ACCESS_DENIED:
          TLogger.Warning(Format('Acesso negado ao servico %s. Execute como administrador.',
            [ServiceName]));
      else
        TLogger.Warning(Format('Falha ao abrir o servico %s: %s',
          [ServiceName, SysErrorMessage(Err)]));
      end;
      Exit;
    end;
    try
      if not QueryServiceStatus(Svc, Status) then
      begin
        TLogger.Warning(Format('Falha ao consultar o servico %s: %s',
          [ServiceName, SysErrorMessage(GetLastError)]));
        Exit;
      end;

      if Status.dwCurrentState = SERVICE_STOPPED then
      begin
        TLogger.Info(Format('Servico %s ja esta parado.', [ServiceName]));
        Exit(True);
      end;

      if Status.dwCurrentState <> SERVICE_STOP_PENDING then
      begin
        TLogger.Info(Format('Parando servico %s...', [ServiceName]));
        if not ControlService(Svc, SERVICE_CONTROL_STOP, Status) then
        begin
          Err := GetLastError;
          if Err = ERROR_SERVICE_NOT_ACTIVE then
          begin
            TLogger.Info(Format('Servico %s ja esta parado.', [ServiceName]));
            Exit(True);
          end;
          TLogger.Warning(Format('Falha ao parar o servico %s: %s',
            [ServiceName, SysErrorMessage(Err)]));
          Exit;
        end;
      end;

      StartedAt := GetTickCount64;
      while Status.dwCurrentState <> SERVICE_STOPPED do
      begin
        if GetTickCount64 - StartedAt >= TimeoutMs then
        begin
          TLogger.Warning(Format('Tempo esgotado aguardando o servico %s parar.',
            [ServiceName]));
          Exit;
        end;
        Sleep(250);
        if not QueryServiceStatus(Svc, Status) then
        begin
          TLogger.Warning(Format('Falha ao consultar o servico %s: %s',
            [ServiceName, SysErrorMessage(GetLastError)]));
          Exit;
        end;
      end;

      TLogger.Info(Format('Servico %s parado.', [ServiceName]));
      Result := True;
    finally
      CloseServiceHandle(Svc);
    end;
  finally
    CloseServiceHandle(SCM);
  end;
end;

function TServiceControl.DeleteService(const ServiceName: string): Boolean;
var SCM, Svc: SC_HANDLE; Err: DWORD;
begin
  Result := False;
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then
  begin
    TLogger.Warning('Nao foi possivel abrir o Service Control Manager: ' +
      SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    Svc := OpenService(SCM, PChar(ServiceName), _DELETE);
    if Svc = 0 then
    begin
      Err := GetLastError;
      if Err = ERROR_SERVICE_DOES_NOT_EXIST then
      begin
        TLogger.Info(Format('Servico %s nao existe.', [ServiceName]));
        Exit(True);
      end;
      TLogger.Warning(Format('Falha ao abrir o servico %s para remocao: %s',
        [ServiceName, SysErrorMessage(Err)]));
      Exit;
    end;
    try
      if Winapi.WinSvc.DeleteService(Svc) then
      begin
        TLogger.Info(Format('Servico %s marcado para remocao.', [ServiceName]));
        Result := True;
      end
      else
      begin
        Err := GetLastError;
        Result := Err = ERROR_SERVICE_MARKED_FOR_DELETE;
        if Result then
          TLogger.Info(Format('Servico %s ja estava marcado para remocao.', [ServiceName]))
        else
          TLogger.Warning(Format('Falha ao remover o servico %s: %s',
            [ServiceName, SysErrorMessage(Err)]));
      end;
    finally
      CloseServiceHandle(Svc);
    end;
  finally
    CloseServiceHandle(SCM);
  end;
end;

function TServiceControl.InstallVgcService(const ServiceName: string; const ServiceExe: string; const DisplayName: string): Boolean;
var
  SCM, Svc: SC_HANDLE;
  PathToExe: string;
  Err: DWORD;
begin
  Result := False;
  PathToExe := ServiceExe;
  if PathToExe = '' then
    PathToExe := TPath.Combine(GetEnvironmentVariable('SystemRoot'), 'System32\svchost.exe');

  SCM := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if SCM = 0 then
  begin
    TLogger.Warning('Nao foi possivel abrir o SCManager para registrar o servico VGC: ' +
      SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    Svc := CreateService(SCM, PChar(ServiceName), PChar(DisplayName),
      SERVICE_START or SERVICE_QUERY_STATUS,
      SERVICE_WIN32_OWN_PROCESS,
      SERVICE_AUTO_START,
      SERVICE_ERROR_NORMAL,
      PChar(PathToExe), nil, nil, nil, nil, nil);
    if Svc = 0 then
    begin
      Err := GetLastError;
      if Err = ERROR_SERVICE_EXISTS then
      begin
        TLogger.Info(Format('Servico %s ja existe.', [ServiceName]));
        Exit(True);
      end;
      TLogger.Warning(Format('Falha ao registrar o servico %s: %s',
        [ServiceName, SysErrorMessage(Err)]));
      Exit;
    end;
    try
      TLogger.Info(Format('Servico %s registrado em %s.', [ServiceName, PathToExe]));
      Result := StartServiceIfNeeded(ServiceName, 15000);
    finally
      CloseServiceHandle(Svc);
    end;
  finally
    CloseServiceHandle(SCM);
  end;
end;

function TServiceControl.StartServiceIfNeeded(const ServiceName: string; TimeoutMs: Cardinal): Boolean;
var
  SCM, Svc: SC_HANDLE;
  Status: TServiceStatus;
  StartedAt: UInt64;
  Err: DWORD;
  ArgVectors: PChar;
begin
  ArgVectors := nil;
  Result := False;
  SCM := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if SCM = 0 then
  begin
    TLogger.Warning('Nao foi possivel abrir o SCManager para iniciar o servico: ' +
      SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    Svc := OpenService(SCM, PChar(ServiceName), SERVICE_START or SERVICE_QUERY_STATUS);
    if Svc = 0 then
    begin
      TLogger.Warning(Format('Servico %s nao foi encontrado para inicializacao.', [ServiceName]));
      Exit;
    end;
    try
      if not QueryServiceStatus(Svc, Status) then
      begin
        Err := GetLastError;
        TLogger.Warning(Format('Falha ao consultar o status do servico %s: %s',
          [ServiceName, SysErrorMessage(Err)]));
        Exit;
      end;
      if Status.dwCurrentState = SERVICE_RUNNING then
      begin
        TLogger.Info(Format('Servico %s ja esta em execucao.', [ServiceName]));
        Exit(True);
      end;

      if not StartService(Svc, 0, ArgVectors) then
      begin
        Err := GetLastError;
        if Err = ERROR_SERVICE_ALREADY_RUNNING then
        begin
          TLogger.Info(Format('Servico %s ja estava em execucao.', [ServiceName]));
          Exit(True);
        end;
        TLogger.Warning(Format('Falha ao iniciar o servico %s: %s',
          [ServiceName, SysErrorMessage(Err)]));
        Exit;
      end;

      StartedAt := GetTickCount64;
      while True do
      begin
        if GetTickCount64 - StartedAt >= TimeoutMs then
        begin
          TLogger.Warning(Format('Tempo esgotado aguardando o servico %s iniciar.',
            [ServiceName]));
          Exit;
        end;
        Sleep(250);
        if not QueryServiceStatus(Svc, Status) then Break;
        if Status.dwCurrentState = SERVICE_RUNNING then
        begin
          TLogger.Info(Format('Servico %s iniciado com sucesso.', [ServiceName]));
          Result := True;
          Break;
        end;
      end;
    finally
      CloseServiceHandle(Svc);
    end;
  finally
    CloseServiceHandle(SCM);
  end;
end;
end.
