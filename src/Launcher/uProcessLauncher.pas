unit uProcessLauncher;
interface
uses System.SysUtils;
type
  TProcessLauncher = class
  public
    procedure Launch(const ExecutablePath, Parameters: string);
  end;
implementation
uses Winapi.Windows, uLogger;
procedure TProcessLauncher.Launch(const ExecutablePath, Parameters: string);
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd, WorkDir: string;
begin
  if not FileExists(ExecutablePath) then
    raise Exception.CreateFmt('Executavel nao encontrado: %s', [ExecutablePath]);
  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);
  SI.cb := SizeOf(SI);
  Cmd := '"' + ExecutablePath + '"';
  if Parameters <> '' then Cmd := Cmd + ' ' + Parameters;
  UniqueString(Cmd);
  WorkDir := ExtractFilePath(ExecutablePath);
  TLogger.Info('Iniciando aplicativo: ' + ExecutablePath);
  if not CreateProcess(nil, PChar(Cmd), nil, nil, False,
    CREATE_NEW_PROCESS_GROUP, nil, PChar(WorkDir), SI, PI) then
    RaiseLastOSError;
  CloseHandle(PI.hThread);
  CloseHandle(PI.hProcess);
end;
end.
