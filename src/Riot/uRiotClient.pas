unit uRiotClient;
interface
uses System.SysUtils;
type
  TRiotClient = class
  private
    function ReadInstallPath: string;
    function FindDefaultInstall: string;
    procedure ApplyProxySettings(const ProxyURL: string);
  public
    function Locate: string;
    procedure LaunchLeague; overload;
    procedure LaunchLeague(const ProxyURL: string); overload;
    procedure CloseRiotProcesses;
    function StopVanguardService: Boolean;
  end;
implementation
uses Winapi.Windows, System.Types, System.IOUtils, System.JSON, uProcessLauncher, uProcessMonitor, uVanguard, uLogger;
function TRiotClient.ReadInstallPath: string;
var JsonPath, Content, Candidate, FileName: string; JsonValue: TJSONValue; Obj: TJSONObject;
begin
  Result := '';
  JsonPath := TPath.Combine(GetEnvironmentVariable('ProgramData'),
    'Riot Games\RiotClientInstalls.json');
  TLogger.Info('Procurando instalacao do Riot Client em: ' + JsonPath);
  if not TFile.Exists(JsonPath) then Exit;
  Content := TFile.ReadAllText(JsonPath, TEncoding.UTF8);
  JsonValue := TJSONObject.ParseJSONValue(Content);
  try
    if not (JsonValue is TJSONObject) then Exit;
    Obj := TJSONObject(JsonValue);
    if Obj.TryGetValue<string>('rc_default', Candidate) and TFile.Exists(Candidate) then
    begin
      FileName := ExtractFileName(Candidate);
      if SameText(FileName, 'RiotClient.exe') or SameText(FileName, 'RiotClientServices.exe') then
        Exit(Candidate);
    end;
    if Obj.TryGetValue<string>('rc_live', Candidate) and TFile.Exists(Candidate) then
    begin
      FileName := ExtractFileName(Candidate);
      if SameText(FileName, 'RiotClient.exe') or SameText(FileName, 'RiotClientServices.exe') then
        Exit(Candidate);
    end;
  finally JsonValue.Free; end;
end;
function TRiotClient.FindDefaultInstall: string;
var BasePath, Candidate, SearchRoot: string; SearchDirs: array[0..7] of string; I: Integer; FoundFiles: TStringDynArray; FileName: string;
begin
  Result := '';
  SearchDirs[0] := TPath.Combine(GetEnvironmentVariable('ProgramFiles'), 'Riot Games');
  SearchDirs[1] := TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'), 'Riot Games');
  SearchDirs[2] := 'C:\Riot Games';
  SearchDirs[3] := 'C:\Program Files\Riot Games';
  SearchDirs[4] := 'C:\Program Files (x86)\Riot Games';
  SearchDirs[5] := TPath.Combine(GetEnvironmentVariable('ProgramW6432'), 'Riot Games');
  SearchDirs[6] := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'Riot Games');
  SearchDirs[7] := TPath.Combine(GetEnvironmentVariable('APPDATA'), 'Riot Games');

  for I := Low(SearchDirs) to High(SearchDirs) do
  begin
    SearchRoot := SearchDirs[I];
    if SearchRoot = '' then Continue;
    TLogger.Info('Procurando em: ' + SearchRoot);
    if not TDirectory.Exists(SearchRoot) then Continue;

    Candidate := TPath.Combine(SearchRoot, 'Riot Client\RiotClient.exe');
    if TFile.Exists(Candidate) then Exit(Candidate);

    Candidate := TPath.Combine(SearchRoot, 'Riot Client\RiotClientServices.exe');
    if TFile.Exists(Candidate) then Exit(Candidate);

    FoundFiles := TDirectory.GetFiles(SearchRoot, 'RiotClient*.exe', TSearchOption.soAllDirectories);
    for FileName in FoundFiles do
    begin
      if SameText(ExtractFileName(FileName), 'RiotClient.exe') or
         SameText(ExtractFileName(FileName), 'RiotClientServices.exe') then
        Exit(FileName);
    end;
  end;

  TLogger.Warning('Riot Client nao encontrado nos caminhos padroes. Caminhos verificados:');
  for I := Low(SearchDirs) to High(SearchDirs) do
  begin
    SearchRoot := SearchDirs[I];
    if SearchRoot <> '' then
      TLogger.Warning(' - ' + SearchRoot);
  end;
end;
function TRiotClient.Locate: string;
begin
  Result := ReadInstallPath;
  if Result = '' then Result := FindDefaultInstall;
  if Result = '' then
    raise Exception.Create('Riot Client nao encontrado. Foram pesquisados os caminhos padroes do Windows e do Riot Games.');
end;
procedure TRiotClient.ApplyProxySettings(const ProxyURL: string);
begin
  if ProxyURL = '' then
  begin
    SetEnvironmentVariable('http_proxy', '');
    SetEnvironmentVariable('https_proxy', '');
    SetEnvironmentVariable('HTTP_PROXY', '');
    SetEnvironmentVariable('HTTPS_PROXY', '');
    Exit;
  end;




  SetEnvironmentVariable(PChar('http_proxy')    ,  PChar(ProxyURL));
  SetEnvironmentVariable(PChar('https_proxy')   , PChar(ProxyURL));
  SetEnvironmentVariable(PChar('HTTP_PROXY')    ,  PChar(ProxyURL));
  SetEnvironmentVariable(PChar('HTTPS_PROXY')   , PChar(ProxyURL));
end;
procedure TRiotClient.LaunchLeague;
begin
  LaunchLeague('');
end;
procedure TRiotClient.LaunchLeague(const ProxyURL: string);
var Exe: string; Launcher: TProcessLauncher; Params: string;
begin
  Exe := Locate;
  if Exe = '' then raise Exception.Create('Riot Client nao encontrado.');
  ApplyProxySettings(ProxyURL);
  if ProxyURL <> '' then
    //SetEnvironmentVariable('SOYUZ_PROXY_URL', ProxyURL);
    SetEnvironmentVariable(PChar('SOYUZ_PROXY_URL'), PChar(ProxyURL));
  TLogger.Info('Riot Client localizado: ' + Exe);
  if ProxyURL <> '' then
    TLogger.Info('Proxy local configurado: ' + ProxyURL);
  TLogger.Info('Iniciando League of Legends pelo Riot Client oficial.');

  Params := '--launch-product=league_of_legends --launch-patchline=live';
  if ProxyURL <> '' then
  begin
    Params := Params + ' --http-proxy=' + ProxyURL;
    Params := Params + ' --proxy-server=' + ProxyURL;
    Params := Params + ' --launch-arguments=--proxy-server=' + ProxyURL;
  end;

  Launcher := TProcessLauncher.Create;
  try
    Launcher.Launch(Exe, Params);
  finally Launcher.Free; end;
end;
procedure TRiotClient.CloseRiotProcesses;
const
  // LeagueClient primeiro; RiotClientServices por ultimo para nao reabrir a UX.
  RiotProcesses: array[0..3] of string = (
    'LeagueClient.exe',
    'RiotClientUxRender.exe',
    'RiotClientUx.exe',
    'RiotClientServices.exe');
var Monitor: TProcessMonitor; Name: string; Total: Integer;
begin
  TLogger.Info('Encerrando processos do Riot...');
  Total := 0;
  Monitor := TProcessMonitor.Create;
  try
    for Name in RiotProcesses do
      Inc(Total, Monitor.TerminateAll(Name));
  finally Monitor.Free; end;
  if Total = 0 then
    TLogger.Info('Nenhum processo do Riot em execucao.')
  else
    TLogger.Info(Format('%d processo(s) do Riot encerrado(s).', [Total]));
end;
function TRiotClient.StopVanguardService: Boolean;
var V: TVanguard;
begin
  V := TVanguard.Create;
  try
    V.Stop;
    Result := True;
  finally V.Free; end;
end;
end.
