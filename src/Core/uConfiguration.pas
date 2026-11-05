unit uConfiguration;
interface
type
  TAppConfig = record
    BackendURL: string;
    LicenseKey: string;
    LaunchPath: string;
    ProxyHost: string;
    ProxyPort: Integer;
    VgcServicePath: string;
    LogToConsole: Boolean;
    SessionPollIntervalMs: Cardinal;
    ClientStartTimeoutMs: Cardinal;
    class function Load: TAppConfig; static;
  end;
implementation
uses System.SysUtils;
class function TAppConfig.Load: TAppConfig;
begin
  Result.BackendURL := Trim(GetEnvironmentVariable('SOYUZ_BACKEND_URL'));
  Result.LicenseKey := Trim(GetEnvironmentVariable('SOYUZ_LICENSE_KEY'));
  Result.LaunchPath := GetEnvironmentVariable('SOYUZ_LAUNCH_PATH');
  Result.ProxyHost := Trim(GetEnvironmentVariable('SOYUZ_PROXY_HOST'));
  Result.ProxyPort := StrToIntDef(GetEnvironmentVariable('SOYUZ_PROXY_PORT'), 0);
  if Result.ProxyHost = '' then
    Result.ProxyHost := '';
  if Result.ProxyPort <= 0 then
    Result.ProxyPort := 0;
  Result.VgcServicePath := Trim(GetEnvironmentVariable('SOYUZ_VGC_SERVICE_PATH'));
  Result.LogToConsole := True;
  Result.SessionPollIntervalMs := 1000;
  Result.ClientStartTimeoutMs := 300000;
end;
end.
