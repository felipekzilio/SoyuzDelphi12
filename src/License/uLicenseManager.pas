unit uLicenseManager;
interface
uses System.SysUtils;
type
  TLicenseManager = class
  private FBackendURL: string;
  public
    constructor Create(const BackendURL: string);
    function Validate(const LicenseKey: string): Boolean;
  end;
implementation
uses System.JSON, uHttpClient, uLogger;
constructor TLicenseManager.Create(const BackendURL: string);
begin
  inherited Create;
  FBackendURL := BackendURL.TrimRight(['/']);
  if FBackendURL = '' then raise Exception.Create('Backend URL nao configurada.');
end;
function TLicenseManager.Validate(const LicenseKey: string): Boolean;
var Client: THttpClient; Payload, Reply, Status: string; Json: TJSONValue; Obj: TJSONObject;
begin
  TLogger.Info('Validando licenca no backend...');
  Payload := TJSONObject.Create.AddPair('key', LicenseKey).ToJSON;
  Client := THttpClient.Create;
  try Reply := Client.PostJson(FBackendURL + '/api/keys/status', Payload);
  finally Client.Free; end;
  Json := TJSONObject.ParseJSONValue(Reply);
  try
    if not (Json is TJSONObject) then raise Exception.Create('Resposta JSON invalida.');
    Obj := TJSONObject(Json);
    if not Obj.TryGetValue<string>('status', Status) then
      raise Exception.Create('Campo status ausente.');
    Result := SameText(Status, 'active') or SameText(Status, 'ok');
  finally Json.Free; end;
end;
end.
