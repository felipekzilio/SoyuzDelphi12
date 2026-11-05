unit uHttpClient;
interface
uses System.SysUtils, System.Net.HttpClient, System.Net.URLClient;
type
  THttpClient = class
  private FClient: System.Net.HttpClient.THTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    function PostJson(const URL, JsonBody: string): string;
  end;
implementation
uses System.Classes;
constructor THttpClient.Create;
begin
  inherited Create;
  FClient := System.Net.HttpClient.THTTPClient.Create;
  FClient.ConnectionTimeout := 10000;
  FClient.ResponseTimeout := 15000;
  FClient.UserAgent := 'Soyuz-Delphi/1.0';
end;
destructor THttpClient.Destroy;
begin FClient.Free; inherited; end;
function THttpClient.PostJson(const URL, JsonBody: string): string;
var Body: TStringStream; Response: IHTTPResponse; Headers: TNetHeaders;
begin
  Body := TStringStream.Create(JsonBody, TEncoding.UTF8);
  try
    SetLength(Headers, 1);
    Headers[0].Name := 'Content-Type';
    Headers[0].Value := 'application/json';
    Response := FClient.Post(URL, Body, nil, Headers);
    if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
      raise Exception.CreateFmt('Backend respondeu HTTP %d: %s',
        [Response.StatusCode, Response.StatusText]);
    Result := Response.ContentAsString(TEncoding.UTF8);
  finally Body.Free; end;
end;
end.
