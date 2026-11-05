unit uProcessMonitor;
interface
uses System.SysUtils;
type
  TProcessMonitor = class
  public
    function IsRunning(const ExeName: string): Boolean;
    /// Encerra todas as instancias do executavel informado.
    /// Retorna quantos processos foram encerrados.
    function TerminateAll(const ExeName: string; WaitMs: Cardinal = 5000): Integer;
  end;
implementation
uses Winapi.Windows, Winapi.TlHelp32, uLogger;
function TProcessMonitor.IsRunning(const ExeName: string): Boolean;
var
  Snapshot: THandle;
  Entry: TProcessEntry32;
begin
  Result := False;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    ZeroMemory(@Entry, SizeOf(Entry));
    Entry.dwSize := SizeOf(Entry);
    if Process32First(Snapshot, Entry) then
      repeat
        if SameText(ExtractFileName(Entry.szExeFile), ExeName) then
          Exit(True);
      until not Process32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;
end;

function TProcessMonitor.TerminateAll(const ExeName: string; WaitMs: Cardinal): Integer;
var
  Snapshot, HProc: THandle;
  Entry: TProcessEntry32;
begin
  Result := 0;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    ZeroMemory(@Entry, SizeOf(Entry));
    Entry.dwSize := SizeOf(Entry);
    if Process32First(Snapshot, Entry) then
      repeat
        if SameText(ExtractFileName(Entry.szExeFile), ExeName) then
        begin
          HProc := OpenProcess(PROCESS_TERMINATE or SYNCHRONIZE, False,
            Entry.th32ProcessID);
          if HProc = 0 then
          begin
            TLogger.Warning(Format('Sem permissao para encerrar %s (PID %d): %s',
              [ExeName, Entry.th32ProcessID, SysErrorMessage(GetLastError)]));
            Continue;
          end;
          try
            if TerminateProcess(HProc, 0) then
            begin
              WaitForSingleObject(HProc, WaitMs);
              Inc(Result);
              TLogger.Info(Format('Processo encerrado: %s (PID %d)',
                [ExeName, Entry.th32ProcessID]));
            end
            else
              TLogger.Warning(Format('Falha ao encerrar %s (PID %d): %s',
                [ExeName, Entry.th32ProcessID, SysErrorMessage(GetLastError)]));
          finally
            CloseHandle(HProc);
          end;
        end;
      until not Process32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;
end;
end.
