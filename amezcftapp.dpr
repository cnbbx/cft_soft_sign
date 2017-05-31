program amezcftapp;

uses
  Forms,
  sign in 'sign.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '艾美e族·云端财富管理系统v1.5';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

