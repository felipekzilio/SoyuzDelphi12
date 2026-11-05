program Soyuz;
{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Winapi.Windows,
  uArguments in 'src\Core\uArguments.pas',
  uConfiguration in 'src\Core\uConfiguration.pas',
  uLogger in 'src\Core\uLogger.pas',
  uServiceControl in 'src\Core\uServiceControl.pas',
  uPassFile in 'src\License\uPassFile.pas',
  uLicenseManager in 'src\License\uLicenseManager.pas',
  uHttpClient in 'src\Network\uHttpClient.pas',
  uProcessLauncher in 'src\Launcher\uProcessLauncher.pas',
  uLocalHttpProxy in 'src\Network\uLocalHttpProxy.pas',
  uVanguard in 'src\Riot\uVanguard.pas',
  uRiotClient in 'src\Riot\uRiotClient.pas',
  uProcessMonitor in 'src\Session\uProcessMonitor.pas',
  uSessionManager in 'src\Session\uSessionManager.pas';

var
  Options: TArguments;
  Config: TAppConfig;
  PassReader: TPassFile;
  Launcher: TProcessLauncher;
  Riot: TRiotClient;
  Vanguard: TVanguard;
  Session: TSessionManager;
  Service: TServiceControl;
  LicenseManager: TLicenseManager;
  Proxy: TLocalHttpProxy;
  PassValue, Target, LicenseKey, ProxyURL: string;
  StepIndex: Integer;

procedure LogStep(const StepName: string; const Status: string = 'OK');
begin
  Inc(StepIndex);
  Writeln(FormatDateTime('hh:nn:ss', Now), ' [', Status, '] Etapa ', StepIndex, ': ', StepName);
end;

begin
  try
    if ParamCount = 0 then
    begin
      Options.Help := False;
      Options.CheckPass := False;
      Options.ValidateLicense := False;
      Options.KillRiot := False;
      Options.LaunchRiot := True;
      Options.RegisterVgc := False;
      Options.LaunchProxy := False;
      Options.ProxyHost := '127.0.0.1';
      Options.ProxyPort := 8080;
      Options.BackendURL := '';
      Options.LicenseKey := '';
      Writeln('Modo auto: sem proxy, sem registro de servico e sem kill agressivo.');
      Writeln('Log gravado em: ' + ExtractFilePath(ParamStr(0)) + 'log.txt');
    end
    else
      Options := TArguments.Parse;

    Config := TAppConfig.Load;
    TLogger.Initialize(Config.LogToConsole);
    TLogger.Info('Soyuz Delphi - inicializando');
    MessageBox(0, 'Soyuz iniciado.', 'Soyuz - Teste', MB_OK or MB_ICONINFORMATION);

    if Options.Help then
    begin
      Writeln('Uso: Soyuz.exe [--check-pass] [--license "key"] [--validate-license] [--proxy] [--register-vgc] [--launch "caminho"] [--riot] [--kill-riot] [--remove-vanguard]');
      Writeln('--validate-license valida a chave no backend remoto configurado.');
      Writeln('--proxy           habilita um proxy HTTP local (127.0.0.1:8080 por padrao).');
      Writeln('--register-vgc    registra/inicializa o servico vgc.');
      Writeln('--kill-riot       encerra os processos do Riot e para o Vanguard (requer administrador).');
      Writeln('--remove-vanguard encerra os processos do Riot, para e desinstala o Vanguard (requer administrador).');
      Writeln('pass.txt deve ficar na mesma pasta do executavel.');
      ExitCode := 0;
      Exit;
    end;

    PassReader := TPassFile.Create;
    try
      PassValue := PassReader.ReadPass;
    finally
      PassReader.Free;
    end;

    if PassValue = '' then
      raise Exception.Create('pass.txt ausente ou vazio.');
    TLogger.Info('pass.txt encontrado e lido. Conteudo oculto.');
    LogStep('Verificacao do pass.txt', 'OK');

    if Options.CheckPass then
    begin
      Writeln('Arquivo pass.txt valido (presente e nao vazio).');
      ExitCode := 0;
      Exit;
    end;

    if Options.BackendURL <> '' then
      Config.BackendURL := Options.BackendURL;
    if Options.LicenseKey <> '' then
      LicenseKey := Options.LicenseKey
    else if Config.LicenseKey <> '' then
      LicenseKey := Config.LicenseKey
    else
      LicenseKey := PassValue;

    if (Options.ValidateLicense or (Options.LicenseKey <> '') or (Config.LicenseKey <> '')) and
       ((Config.BackendURL <> '') or (Options.BackendURL <> '')) then
    begin
      if Config.BackendURL = '' then
        Config.BackendURL := Options.BackendURL;
      LicenseManager := TLicenseManager.Create(Config.BackendURL);
      try
        if not LicenseManager.Validate(LicenseKey) then
          raise Exception.Create('Licenca invalida ou expirada no backend remoto.');
      finally
        LicenseManager.Free;
      end;
      LogStep('Validacao da licenca no backend', 'OK');
    end
    else
      LogStep('Validacao da licenca', 'SKIP');

    if Options.RegisterVgc then
    begin
      Service := TServiceControl.Create;
      try
        if not Service.InstallVgcService('vgc', Config.VgcServicePath, 'vgc') then
          raise Exception.Create('Falha ao registrar o servico vgc.');
      finally
        Service.Free;
      end;
      LogStep('Registro do servico vgc', 'OK');
    end;

    if Options.LaunchProxy or ((Config.ProxyPort > 0) and (Config.ProxyHost <> '')) then
    begin
      Proxy := TLocalHttpProxy.Create(Config.ProxyHost, Config.ProxyPort);
      try
        Proxy.Start;
        ProxyURL := Proxy.Endpoint;
      finally
        Proxy.Free;
      end;
      LogStep('Proxy HTTP local', 'OK');
    end;

    if Options.KillRiot or Options.RemoveVanguard then
    begin
      Riot := TRiotClient.Create;
      try
        Riot.CloseRiotProcesses;
        Riot.StopVanguardService;
      finally
        Riot.Free;
      end;
      if Options.RemoveVanguard then
      begin
        Vanguard := TVanguard.Create;
        try
          if not Vanguard.Uninstall then
            raise Exception.Create('Nao foi possivel desinstalar o Vanguard.');
        finally
          Vanguard.Free;
        end;
      end;
      LogStep('Limpeza do Riot / Vanguard', 'OK');
      if not Options.LaunchRiot then
      begin
        ExitCode := 0;
        Exit;
      end;
    end;

    if Options.LaunchRiot then
    begin
      Riot := TRiotClient.Create;
      try
        Riot.LaunchLeague(ProxyURL);
      finally
        Riot.Free;
      end;
      LogStep('Inicializacao do Riot Client', 'OK');

      Session := TSessionManager.Create(Config.SessionPollIntervalMs,
          Config.ClientStartTimeoutMs);
      try
        Session.Run;
      finally
        Session.Free;
      end;
    end
    else
    begin
      Target := Options.LaunchPath;
      if Target = '' then
        Target := Config.LaunchPath;
      if Target <> '' then
      begin
        Launcher := TProcessLauncher.Create;
        try
          Launcher.Launch(Target, '');
        finally
          Launcher.Free;
        end;
      end
      else
        Writeln('Verificacao local aprovada. Use --riot ou --launch "caminho".');
    end;
    if ParamCount = 0 then
    begin
      Writeln('Execucao concluida. Pressione Enter para sair.');
      Readln;
    end;

    ExitCode := 0;
  except
    on E: Exception do
    begin
      TLogger.Error(E.Message);
      Writeln(ErrOutput, 'Erro: ', E.Message);
      if ParamCount = 0 then
      begin
        Writeln('Pressione Enter para sair.');
        Readln;
      end;
      ExitCode := 1;
    end;
  end;
end.
