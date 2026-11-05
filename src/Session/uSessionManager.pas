unit uSessionManager;
interface
uses System.SysUtils;
type
  TSessionManager = class
  private
    FPollIntervalMs: Cardinal;
    FClientStartTimeoutMs: Cardinal;
    procedure WaitForLeagueClient;
    procedure MonitorLeagueClient;
  public
    constructor Create(PollIntervalMs, ClientStartTimeoutMs: Cardinal);
    procedure Run;
  end;
implementation
uses Winapi.Windows, uProcessMonitor, uLogger;
constructor TSessionManager.Create(PollIntervalMs, ClientStartTimeoutMs: Cardinal);
begin
  inherited Create;
  FPollIntervalMs := PollIntervalMs;
  if FPollIntervalMs < 250 then FPollIntervalMs := 250;
  FClientStartTimeoutMs := ClientStartTimeoutMs;
end;

procedure TSessionManager.WaitForLeagueClient;
var Monitor: TProcessMonitor; StartedAt: UInt64;
begin
  Monitor := TProcessMonitor.Create;
  try
    StartedAt := GetTickCount64;
    TLogger.Info('Aguardando LeagueClient.exe...');
    while not Monitor.IsRunning('LeagueClient.exe') do
    begin
      if (FClientStartTimeoutMs > 0) and
         (GetTickCount64 - StartedAt >= FClientStartTimeoutMs) then
        raise Exception.Create('Tempo esgotado aguardando League Client.');
      Sleep(FPollIntervalMs);
    end;
    TLogger.Info('League Client detectado.');
  finally Monitor.Free; end;
end;

procedure TSessionManager.MonitorLeagueClient;
var Monitor: TProcessMonitor; GameWasSeen, GameRunning: Boolean;
begin
  Monitor := TProcessMonitor.Create;
  GameWasSeen := False;
  try
    TLogger.Info('Monitorando sessao do cliente...');
    repeat
      GameRunning := Monitor.IsRunning('League of Legends.exe');
      if GameRunning and not GameWasSeen then
      begin
        GameWasSeen := True;
        TLogger.Info('Processo do jogo detectado.');
      end
      else if (not GameRunning) and GameWasSeen then
      begin
        GameWasSeen := False;
        TLogger.Info('Processo do jogo encerrado.');
      end;
      if Monitor.IsRunning('LeagueClient.exe') then
        Sleep(FPollIntervalMs)
      else
        Break;
    until False;

    if GameWasSeen then
      TLogger.Warning('League Client encerrou enquanto o processo do jogo ainda constava ativo.');
    TLogger.Info('League Client encerrado. Sessao finalizada.');
  finally Monitor.Free; end;
end;

procedure TSessionManager.Run;
begin
  TLogger.Info('Aguardando inicializacao da sessao.');
  WaitForLeagueClient;
  MonitorLeagueClient;
end;
end.
