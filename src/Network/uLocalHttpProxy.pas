unit uLocalHttpProxy;

interface

uses
  System.SysUtils;

type
  TLocalHttpProxy = class
  private
    FHost: string;
    FPort: Integer;
  public
    constructor Create(const Host: string = '127.0.0.1'; const Port: Integer = 8080);
    procedure Start;
    procedure Stop;
    function Endpoint: string;
  end;

implementation

uses
  Winapi.Windows, uLogger;

constructor TLocalHttpProxy.Create(const Host: string; const Port: Integer);
begin
  inherited Create;
  FHost := Host;
  if FHost = '' then
    FHost := '127.0.0.1';
  FPort := Port;
  if FPort <= 0 then
    FPort := 8080;
end;

procedure TLocalHttpProxy.Start;
var
  ProxyURL: string;
begin
  ProxyURL := 'http://' + FHost + ':' + IntToStr(FPort);

  SetEnvironmentVariable(PChar('http_proxy'), PChar(ProxyURL));
  SetEnvironmentVariable(PChar('https_proxy'), PChar(ProxyURL));
  SetEnvironmentVariable(PChar('HTTP_PROXY'), PChar(ProxyURL));
  SetEnvironmentVariable(PChar('HTTPS_PROXY'), PChar(ProxyURL));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_HOST'), PChar(FHost));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_PORT'), PChar(IntToStr(FPort)));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_URL'), PChar(ProxyURL));

  TLogger.Info('Proxy HTTP local habilitado em ' + ProxyURL + '.');
  TLogger.Info('Variaveis de ambiente do proxy configuradas para o Riot Client.');
end;

procedure TLocalHttpProxy.Stop;
begin
  SetEnvironmentVariable(PChar('http_proxy'), PChar(''));
  SetEnvironmentVariable(PChar('https_proxy'), PChar(''));
  SetEnvironmentVariable(PChar('HTTP_PROXY'), PChar(''));
  SetEnvironmentVariable(PChar('HTTPS_PROXY'), PChar(''));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_URL'), PChar(''));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_HOST'), PChar(''));
  SetEnvironmentVariable(PChar('SOYUZ_PROXY_PORT'), PChar(''));
  TLogger.Info('Proxy HTTP local desativado.');
end;

function TLocalHttpProxy.Endpoint: string;
begin
  Result := 'http://' + FHost + ':' + IntToStr(FPort);
end;

end.
