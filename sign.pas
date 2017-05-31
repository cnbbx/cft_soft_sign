unit sign;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, OleCtrls, SHDocVw, AppEvnts, Comobj, ActiveX, MD5, DateUtils, wininet, Registry, shellAPI;

type
  TForm1 = class(TForm)
    WebBrowser1: TWebBrowser;
    ApplicationEvents1: TApplicationEvents;
    procedure FormCreate(Sender: TObject);
    procedure WebBrowser1DocumentComplete(Sender: TObject;
      const pDisp: IDispatch; var URL: OleVariant);
    procedure ApplicationEvents1Message(var Msg: tagMSG; var Handled: Boolean);
    procedure WebBrowser1BeforeNavigate2(Sender: TObject;
      const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
      Headers: OleVariant; var Cancel: WordBool);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure HotKey(var Msg: Tmessage); message WM_HOTKEY;
  end;

  TMyThread = class(TThread)
  private
     { Private declarations }
  protected
    procedure Execute; override; {执行}
    procedure Run; {声明多一个过程，把功能代码写在这里再给Execute调用}
  end;

var
  Form1: TForm1;
  FrmKey: TForm1;
  urlstr, drive, mac: string;
implementation

{$R *.dfm}
var MyThread: TMyThread;

procedure TMyThread.Execute;
begin
  { Place thread code here }
  FreeOnTerminate := True; {加上这句线程用完了会自动注释}
  Run;
end;

function GetLastInput: integer; //获取闲置时间
var
  LInput: TLastInputInfo;
begin
  Result := 0;
  try
    LInput.cbSize := SizeOf(TLastInputInfo);
    GetLastInputInfo(LInput);
    Result := ((GetTickCount - LInput.dwTime) div 1000);
  except
  end;
end;

procedure TMyThread.Run;
begin
  while true do
  try
    Sleep(1000);
    if GetLastInput() > 60 * 60 then
      ShowMessage('亲，你都超过1个小时没有理我啦！');
  except
  end;
end;

function GetWMIProperty(WMIType, WMIProperty: string): string; //获得硬盘序列号
var Wmi, Objs, Obj: OleVariant;
  C: Cardinal;
  tempItem: IEnumVariant;
begin
  //ShowMessage('jinge：GetWMIProperty001');
  Wmi := CreateOleObject('WbemScripting.SWbemLocator');
  Objs := Wmi.ConnectServer('.', 'root\cimv2').ExecQuery('Select * from Win32_' + WMIType + ' WHERE Index = 0');
  tempItem := IEnumVariant(IUnknown(Objs._NewEnum));
  Result := '';
  //ShowMessage('jinge：GetWMIProperty002');
  while (tempItem.Next(1, obj, c) = S_OK) do
  begin
    //ShowMessage('jinge：GetWMIProperty003');
    try
      Obj := Obj.Properties_.Item(WMIProperty, 0);
    except
      on E: Exception do
        obj := trim('jinge');
    end;
    //ShowMessage('jinge：GetWMIProperty004');
    if not VarIsNull(obj) then
    begin
      //ShowMessage('jinge：GetWMIProperty005');
      Result := trim(Obj);
      break;
    end;
  end;
end;

function MacAddress: string; //获取MAC地址
var
  Lib: Cardinal;
  Func: function(GUID: PGUID): Longint;
  stdcall;
  GUID1, GUID2: TGUID;
begin
  //ShowMessage('jinge：MacAddress001');
  Result := '';
  Lib := LoadLibrary('rpcrt4.dll');
  if Lib <> 0 then
  begin
    if Win32Platform <> VER_PLATFORM_WIN32_NT then
      @Func := GetProcAddress(Lib, 'UuidCreate')
    else
      @Func := GetProcAddress(Lib, 'UuidCreateSequential');
    if Assigned(Func) then
    begin
      //ShowMessage('jinge：MacAddress002');
      if (Func(@GUID1) = 0) and (Func(@GUID2) = 0) and
        (GUID1.D4[2] = GUID2.D4[2]) and (GUID1.D4[3] = GUID2.D4[3]) and
        (GUID1.D4[4] = GUID2.D4[4]) and (GUID1.D4[5] = GUID2.D4[5]) and
        (GUID1.D4[6] = GUID2.D4[6]) and (GUID1.D4[7] = GUID2.D4[7]) then
      begin
        Result := IntToHex(GUID1.D4[2], 2) + ':' + IntToHex(GUID1.D4[3], 2)
          + ':' + IntToHex(GUID1.D4[4], 2) + ':' + IntToHex(GUID1.D4[5], 2)
          + ':' + IntToHex(GUID1.D4[6], 2) + ':' + IntToHex(GUID1.D4[7], 2);
      end;
    end;
    FreeLibrary(Lib);
    //ShowMessage('jinge：MacAddress003');
  end;
end;

function getrand(n: integer): string;
var
  i: integer;
  rangstr: string;
begin
  randomize;
  for i := 0 to n do
  begin
    rangstr := rangstr + inttostr(random(9));
  end;
  result := rangstr;
end;

function UnixDateToDateTime: string; //Unix时间戳
begin
  Result := Format('%u', [DateTimeToUnix(Now) - 8 * 60 * 60]);
end;

function InetIsOffline(Flag: Integer): Boolean; stdcall; external 'URL.DLL';

function ConnectionKind: boolean; //检测网络状态
var flags: dword;
begin
  Result := InternetGetConnectedState(@flags, 0);
  if Result then
  begin
    if (flags and INTERNET_CONNECTION_MODEM) = INTERNET_CONNECTION_MODEM then showmessage('在线：拨号上网');
    if (flags and INTERNET_CONNECTION_LAN) = INTERNET_CONNECTION_LAN then showmessage('在线：通过局域网');
    if (flags and INTERNET_CONNECTION_PROXY) = INTERNET_CONNECTION_PROXY then showmessage('在线：代理');
    if (flags and INTERNET_CONNECTION_MODEM_BUSY) = INTERNET_CONNECTION_MODEM_BUSY then showmessage('MODEM被其他非INTERNET连接占用');
  end;
end;

procedure TForm1.FormCreate(Sender: TObject); //WebBrowser初始页
var reval: string;
var reg: TRegistry;
  _HotKey: Integer;
begin
  _HotKey := GlobalAddAtom('HotKey') - $C000;
  RegisterHotKey(Handle, _HotKey, 0, VK_F1);
  RegisterHotKey(Handle, _HotKey, 0, VK_F2);
  RegisterHotKey(Handle, _HotKey, 0, VK_F4);
  reg := TRegistry.Create;
  reg.RootKey := HKEY_CURRENT_USER;
  //if reg.OpenKey('\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION', true) then
  //begin
  //  reg.WriteInteger(ExtractFileName(Application.ExeName), 8000);
  //  reg.CloseKey;
  //  reg.free;
  //end;
  webbrowser1.Navigate('about:blank');
  WebBrowser1.Silent := True;
  reval := '';
  reval := reval + '<!DOCTYPE html>';
  reval := reval + '<html>';
  reval := reval + '<head>';
  reval := reval + '<!–[if lte IE 8]>';
  reval := reval + '<meta http-equiv="x-ua-compatible" content="ie=8" />';
  reval := reval + '<![endif]–>';
  reval := reval + '<!–[if IE 9]>';
  reval := reval + '<meta http-equiv="x-ua-compatible" content="ie=9" />';
  reval := reval + '<![endif]–>';
  reval := reval + '<style>';
  reval := reval + '#fire {';
  reval := reval + 'text-align: center;';
  reval := reval + 'margin: 200px auto;';
  reval := reval + 'font-family: "Comic Sans MS";';
  reval := reval + 'font-size: 80px;';
  reval := reval + 'color: #efefef;';
  reval := reval + 'text-shadow: 0 0 20px #fefcc9, 10px -10px 30px #feec85, -20px -20px 40px #ffae34, 20px -40px 50px #ec760c, -20px -60px 60px #cd4606, 0 -80px 70px #973716, 10px -90px 80px #451b0e;';
  reval := reval + '}';
  reval := reval + 'html {';
  reval := reval + 'height:100%;';
  reval := reval + '}';
  reval := reval + 'body {';
  reval := reval + 'height:100%;margin:0;padding:0;FILTER: progid:DXImageTransform.Microsoft.Gradient(gradientType=0,startColorStr=#b8c4cb,endColorStr=blue); /*IE 6 7 8*/ ';
  reval := reval + '}';
  reval := reval + '</style>';
  reval := reval + '</head>';
  reval := reval + '<body>';
  reval := reval + '<h1 id="fire">Loading...</h1>';
  reval := reval + '</body>';
  reval := reval + '</html>';
  WebBrowser1.OleObject.Document.Writeln(reval);
  if 1 = 2 then
  begin
    ShowMessage('没有连接到网络!');
    ExitProcess(0); Application.Terminate;
  end
  else
  begin
    drive := GetWMIProperty('DiskDrive', 'SerialNumber');
    mac := MacAddress;
    if trim(drive) = 'jinge' then
    begin
      reg := TRegistry.Create;
      reg.RootKey := HKEY_CURRENT_USER;
      if (not reg.KeyExists('\Software\amez999.com')) then
      begin
        if reg.OpenKey('\Software\amez999.com', true) then
        begin
          drive := getrand(10);
          reg.WriteString('cnbbx', drive);
          reg.CloseKey;
          reg.free;
        end
      end
      else
      begin
        if reg.OpenKey('\Software\amez999.com', true) then
        begin
          drive := reg.ReadString('cnbbx');
        end
      end;
    end
  end;
  urlstr := 'http://www.amez999.com';
  //urlstr := 'http://nc.cnbbx.com';
  WebBrowser1.Navigate(urlstr + '/store/index.php?act=index&op=login&var=v1.5&drive=' + drive + '&mac=' + mac + '&openid=' + MD5.StrToMD5(drive + 'cnbbx' + mac) + '&time=' + UnixDateToDateTime);
  MyThread := TMyThread.Create(False);
end;

procedure TForm1.HotKey(var Msg: Tmessage);
begin
  if (Msg.LParamHi = VK_F1) then
  begin
    if self.Visible then
    begin
      WebBrowser1.Navigate(urlstr + '/store/index.php?act=index&op=login&var=debug&drive=' + drive + '&mac=' + mac + '&openid=' + MD5.StrToMD5(drive + 'cnbbx' + mac) + '&time=' + UnixDateToDateTime);
    end;
  end;
  if (Msg.LParamHi = VK_F2) then
  begin
    if self.Visible then
    begin
      WebBrowser1.Navigate(urlstr + '/store/index.php?act=index&op=login&var=v1.5&drive=' + drive + '&mac=' + mac + '&openid=' + MD5.StrToMD5(drive + 'cnbbx' + mac) + '&time=' + UnixDateToDateTime);
    end;
  end;
  if (Msg.LParamHi = VK_F4) then
  begin
    if self.Visible then
    begin
      ShellExecute(handle, nil, pchar(urlstr + '/store/index.php?act=index&op=login&var=v1.5&drive=' + drive + '&mac=' + mac + '&openid=' + MD5.StrToMD5(drive + 'cnbbx' + mac) + '&time=' + UnixDateToDateTime), nil, nil, sw_shownormal);
      ExitProcess(0); Application.Terminate;
    end;
  end;
end;

procedure TForm1.WebBrowser1DocumentComplete(Sender: TObject;
  const pDisp: IDispatch; var URL: OleVariant); //WebBrowser设置
begin
  WebBrowser1.OleObject.Document.Body.Scroll := 'no';
  WebBrowser1.OleObject.Document.Body.style.border := 'none';
  webbrowser1.OleObject.Document.Body.Style.margin := '0px';
end;

procedure TForm1.ApplicationEvents1Message(var Msg: tagMSG; var Handled: Boolean); //WebBrowser禁止右键
begin
  if (Msg.message = wm_rbuttondown) or (Msg.message = wm_rbuttonup) or
    (msg.message = WM_RBUTTONDBLCLK) then
  begin
    if IsChild(Webbrowser1.Handle, Msg.hwnd) then
      Handled := true;
  end;
end;

procedure TForm1.WebBrowser1BeforeNavigate2(Sender: TObject;
  const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
  Headers: OleVariant; var Cancel: WordBool); //检测是否退出按钮
var ExitFlag: Integer; //退出标志
begin
  if Pos('#exit', URL) > 0 then
  begin
    ExitFlag := Application.MessageBox('确认退出吗?', '警告', Mb_YesNo);
    if ExitFlag = 7 then //不退出
    begin
      Exit;
    end
    else
    begin
      self.close; //退出
    end;
    Cancel := True;
  end;
end;


end.

