unit uLogger;
interface
type
  TLogger = class
  public
    class procedure Initialize(WriteConsole: Boolean); static;
    class procedure Info(const Msg: string); static;
    class procedure Warning(const Msg: string); static;
    class procedure Error(const Msg: string); static;
  end;
implementation
uses System.SysUtils, System.IOUtils;
var GWriteConsole: Boolean = True;
    GLogFile: string = '';

class procedure TLogger.Initialize(WriteConsole: Boolean);
var LogPath: string;
begin
  GWriteConsole := WriteConsole;
  LogPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'log.txt');
  GLogFile := LogPath;
  if FileExists(GLogFile) then
    TFile.Delete(GLogFile);
end;

class procedure TLogger.Info(const Msg: string);
begin
  if GWriteConsole then
    Writeln(FormatDateTime('hh:nn:ss', Now), ' [INFO] ', Msg);
  if GLogFile <> '' then
    TFile.AppendAllText(GLogFile, FormatDateTime('hh:nn:ss', Now) + ' [INFO] ' + Msg + sLineBreak, TEncoding.UTF8);
end;

class procedure TLogger.Warning(const Msg: string);
begin
  if GWriteConsole then
    Writeln(FormatDateTime('hh:nn:ss', Now), ' [AVISO] ', Msg);
  if GLogFile <> '' then
    TFile.AppendAllText(GLogFile, FormatDateTime('hh:nn:ss', Now) + ' [AVISO] ' + Msg + sLineBreak, TEncoding.UTF8);
end;

class procedure TLogger.Error(const Msg: string);
begin
  if GWriteConsole then
    Writeln(ErrOutput, FormatDateTime('hh:nn:ss', Now), ' [ERRO] ', Msg);
  if GLogFile <> '' then
    TFile.AppendAllText(GLogFile, FormatDateTime('hh:nn:ss', Now) + ' [ERRO] ' + Msg + sLineBreak, TEncoding.UTF8);
end;
end.
