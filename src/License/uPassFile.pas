unit uPassFile;
interface
uses System.SysUtils;
type
  TPassFile = class
  private
    FFileName: string;
  public
    constructor Create;
    function ReadPass: string;
    property FileName: string read FFileName;
  end;
implementation
uses System.IOUtils;
constructor TPassFile.Create;
begin
  inherited Create;
  FFileName := TPath.Combine(ExtractFilePath(ParamStr(0)), 'pass.txt');
end;
function TPassFile.ReadPass: string;
begin
  Result := '';
  if not TFile.Exists(FFileName) then
    raise Exception.Create('Arquivo nao encontrado: ' + FFileName);
  Result := Trim(TFile.ReadAllText(FFileName, TEncoding.UTF8));
  if Result = '' then
    raise Exception.Create('O arquivo pass.txt esta vazio.');
end;
end.
