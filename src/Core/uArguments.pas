unit uArguments;
interface
type
  TArguments = record
    Help: Boolean;
    CheckPass: Boolean;
    ValidateLicense: Boolean;
    LaunchRiot: Boolean;
    KillRiot: Boolean;
    RemoveVanguard: Boolean;
    RegisterVgc: Boolean;
    LaunchProxy: Boolean;
    LicenseKey: string;
    BackendURL: string;
    ProxyHost: string;
    ProxyPort: Integer;
    LaunchPath: string;
    class function Parse: TArguments; static;
  end;
implementation
uses System.SysUtils;
class function TArguments.Parse: TArguments;
var I: Integer; Arg: string;
begin
  Result := Default(TArguments);
  Result.ProxyHost := '';
  Result.ProxyPort := 0;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if SameText(Arg, '--help') or SameText(Arg, '-h') then Result.Help := True
    else if SameText(Arg, '--check-pass') then Result.CheckPass := True
    else if SameText(Arg, '--validate-license') then Result.ValidateLicense := True
    else if SameText(Arg, '--license') then
    begin
      Inc(I);
      if I > ParamCount then raise Exception.Create('--license exige um valor.');
      Result.LicenseKey := ParamStr(I);
    end
    else if SameText(Arg, '--backend-url') then
    begin
      Inc(I);
      if I > ParamCount then raise Exception.Create('--backend-url exige uma URL.');
      Result.BackendURL := ParamStr(I);
    end
    else if SameText(Arg, '--proxy-host') then
    begin
      Result.LaunchProxy := True;
      Inc(I);
      if I > ParamCount then raise Exception.Create('--proxy-host exige um valor.');
      Result.ProxyHost := ParamStr(I);
    end
    else if SameText(Arg, '--proxy-port') then
    begin
      Result.LaunchProxy := True;
      Inc(I);
      if I > ParamCount then raise Exception.Create('--proxy-port exige um valor numerico.');
      Result.ProxyPort := StrToIntDef(ParamStr(I), 8080);
    end
    else if SameText(Arg, '--proxy') then
    begin
      Result.LaunchProxy := True;
      if Result.ProxyHost = '' then Result.ProxyHost := '127.0.0.1';
      if Result.ProxyPort <= 0 then Result.ProxyPort := 8080;
    end
    else if SameText(Arg, '--register-vgc') then Result.RegisterVgc := True
    else if SameText(Arg, '--riot') then Result.LaunchRiot := True
    else if SameText(Arg, '--kill-riot') then Result.KillRiot := True
    else if SameText(Arg, '--remove-vanguard') then Result.RemoveVanguard := True
    else if SameText(Arg, '--launch') then
    begin
      Inc(I);
      if I > ParamCount then raise Exception.Create('--launch exige um caminho.');
      Result.LaunchPath := ParamStr(I);
    end
    else raise Exception.CreateFmt('Argumento desconhecido: %s', [Arg]);
    Inc(I);
  end;
  if Result.LaunchProxy then
  begin
    if Result.ProxyHost = '' then Result.ProxyHost := '127.0.0.1';
    if Result.ProxyPort <= 0 then Result.ProxyPort := 8080;
  end;
  if Result.RemoveVanguard and Result.LaunchRiot then
    raise Exception.Create('--remove-vanguard nao pode ser usado com --riot.');
end;
end.
