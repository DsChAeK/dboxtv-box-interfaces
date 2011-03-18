// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       dboxTV_neutrinohd.dll - a box interface dll for dboxTV
//   Version:       1.0
//
//   Function:      DLL functions
//
//   License:       Copyright (c) 2009, DsChAeK
//
//                  Permission to use, copy, modify, and/or distribute this software for any purpose
//                  with or without fee is hereby granted, provided that the above copyright notice
//                  and this permission notice appear in all copies.
//
//                  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
//                  REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
//                  FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT,
//                  OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
//                  DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
//                  ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// ##############################################################################################
//
// Info: This DLL enables the communication between dboxTV and NeutrinoHD.
//       It may be used as a template for other box interfaces.
//       This DLL provides functionality for the current selected box in dboxTV!
//       All transfered data types are compatible with other languages, so you
//       don't have to use delphi and this code! All functions use stdcall!
//
//       data flow:  dboxTV -> DLL -> box webinterface -> dboxTV
//
//       -> e.g. dboxTV wants the current channel id
//          1. dboxTV calls the DLL function GetCurrentChannelID()
//          2. DLL function calls GetURL(URL_DBOX_ZAPTO) and returns the data
//          3. dboxTV uses the data in context
//
//       All functions were created in relationship to neutrinoHD so there is a
//       high possibility to miss a function or parameter which is needed for
//       other interfaces and future use.
//       If you miss something plz send me an email to admin@dschaek.de or visit
//       my developer forum http://forum.dschaek.de/board.php?boardid=30
//
//       To transfer bouquet data between dll and application, dboxTV will give
//       you some function pointers with the Init() function which you have to
//       use for adding bouquets/channels and channelprograms (e.g. AddBouquet()).
//       The function pointers are declared in UntDataDLL.pas.
//
//       To understand the function-handling you have to know the structure:
//
//        bouquet 1 (AddBouquet(Bouquet1))
//           |
//         channel 1 (AddChannel(Bouquet1Index, Channel))
//              |
//            channelprogram 1  (AddChannelProgram(ChannelIndex, ChannelProgram))
//            channelprogram 2  (AddChannelProgram(ChannelIndex, ChannelProgram))
//            ...
//           |
//         channel 2 (AddChannel(Bouquet1Index, Channel))
//          ...
//
//        bouquet 2 (AddBouquet(Bouquet2))
//         ...
//
//       These functions, except AddChannelProgram(), will log the given data in
//       dboxTV if 'Log HTTP' is enabled. For AddChannelProgram() you have
//       to enable 'Log EPG' in dboxTV->Options->Advanced.
//       You can always log directly into the 'dboxTV.log' via Log(), you
//       don't need to implement your own logging.
//
//       There are also function pointers for http/regex/telnet functionality of dboxTV
//       you can use, but you don't have to:
//
//       1.) HTTP
//       Have a look ar UntHttpClient.pas and Init() to understand how you can
//       get data from your box via http communication over the dboxTV http client.
//       It is based on TIEHTTPD from Kyriacos Michael, which is using the wininet.dll.
//       Html special chars and utf8 will be translated automatically.
//
//       2.) REGEX
//       All parsing is done via regex functionality of dboxTV and with a little
//       'know how' it is very adaptable to other circumstances.
//       dboxTV uses TRegExpr from Andrey V. Sorokin (http://anso.virtualave.net/)
//       I recommend using "TestRegExp.exe" to find the best way parsing data, if
//       it is working there, it will be working inside this dll.
//       Plz have a look at UntRegEx.pas and Init() to understand how TRegExpr
//       works and how to implement the dboxTV functions.
//       Html special chars and utf8 will be translated automatically.
//
//       3.) TELNET
//       Just a Function to send a command to the dboxTV telnet console
//       (login in dboxTV required)
//
// Important: -All box functions should be implemented completely and correctly or
//             dboxTV shows undefined behaviour!
//            -The http client used in dboxTV is not thread safe so therefore the
//             FktGetURL_EPG is needed.
//            -dboxTV telnet component is asynchron, so you have to use a delay!
//
// Files:    -dboxTV_neutrinohd.dpr -> all dll functions and export
//           -UntURL.pas            -> box specific urls
//           -UntHelpers.pas        -> useful string handling functions
//           -UntHttpClient.pas     -> http request handling using dboxTV functions
//           -UntRegEx.pas          -> regex handling using dboxTV functions
//           -UntDataDLL.pas        -> data structures/function pointers for exchange
//                                     with dboxTV
//
// ##############################################################################################

library dboxtv_neutrinohd;

uses
  sysutils,
  windows,
  classes,
  UntURL in 'UntURL.pas',
  UntDataDLL in '..\UntDataDLL.pas',
  UntHelpers in '..\UntHelpers.pas',
  UntHttpClient in '..\UntHttpClient.pas',
  UntRegEx in '..\UntRegEx.pas';

{$IFDEF WINDOWS}{$R dboxTV_neutrinohd.rc}{$ENDIF}
{$LongStrings ON}

{$R *.RES}

// ##############################################################################################
// ################################### info #####################################################
// ##############################################################################################
const
  AUTHOR  = 'DsChAeK';               // author info for dboxtv about box
  VERSION = 'v1';                    // version info for dboxtv about box
  BOXNAME = 'Coolstream NeutrinoHD'; // boxname info for dboxtv display

// ##############################################################################################
// ################################### vars #####################################################
// ##############################################################################################
var
  // variables
  HttpClient : THttpClient; // http client

  RegEx         : TRegEx; // regex for general usage
  RegExChannels : TRegEx; // regex for channels
  RegExServices : TRegEx; // regex for services

  // global function pointers
  GetBoxData        : TDLL_GetBoxData;        // dboxTV function to get current box data
  Log               : TDLL_LogStr;            // dboxTV log function
  SendTelnetCmd     : TDLL_SendTelnetCmd;     // dboxTV telnet function
  AddBouquet        : TDLL_AddBouquet;        // dboxTV function to add a bouquet
  AddChannel        : TDLL_AddChannel;        // dboxTV function to add a channel
  AddChannelProgram : TDLL_AddChannelProgram; // dboxTV function to add a channel program
  FreePChar         : TDLL_FreePChar;         // dboxTV function to dispose pchar mem
  
// ###########################################################################
// ############################ handling functions ###########################
// ###########################################################################

(*******************************************************************************
 * INFO:
 *   init function, called first by dboxTV
 *
 * PARAMS:
 *   FktGetBoxData        : pointer to dboxTV get box data function
 *   FktLog               : pointer to dboxTV log function
 *   FktAddBouquet        : pointer to dboxTV add bouquet function
 *   FktAddChannel        : pointer to dboxTV add channel function
 *   FktAddChannelProgram : pointer to dboxTV add channel program function
 *   FktSendTelnetCmd     : pointer to dboxTV send telnet command function
 *   FktFreePChar         : pointer to function which dispose pchar mem
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function Init (FktGetBoxData, FktLog, FktAddBouquet, FktAddChannel, FktAddChannelProgram, FktSendTelnetCmd, FktFreePChar : Pointer):ByteBool; stdcall;
begin
  Result := true;

  try
    // set global function pointers
    TMethod(GetBoxData).Code := FktGetBoxData;
    TMethod(Log).Code := FktLog;
    TMethod(AddBouquet).Code := FktAddBouquet;
    TMethod(AddChannel).Code := FktAddChannel;
    TMethod(AddChannelProgram).Code := FktAddChannelProgram;
    TMethod(SendTelnetCmd).Code := FktSendTelnetCmd;
    TMethod(FreePChar).Code := FktFreePChar;
    
  except
    Result := false;
  end;
end;

(*******************************************************************************
 * INFO:
 *   init function for http requests, called first by dboxTV
 *   if not needed just return true!
 *
 * PARAMS:
 *   FktGetURL     : pointer to dboxTV get url function
 *   FktGetURL_BIN : pointer to dboxTV get url function for binary data
 *   FktGetURL_EPG : pointer to dboxTV get url function for epg data
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function InitHttp (FktGetURL, FktGetURL_BIN, FktGetURL_EPG : Pointer):ByteBool; stdcall;
begin
  Result := true;

  try

    // create http client here
    if not Assigned(HttpClient) then
      HttpClient := THttpClient.Create(TMethod(GetBoxData).Code, TMethod(Log).Code, FktGetURL, FktGetURL_BIN, FktGetURL_EPG, @FreePChar);

  except
    Result := false;
  end;
end;

(*******************************************************************************
 * INFO:
 *   init function for regex requests, called first by dboxTV
 *   if not needed just return true!
 *
 * PARAMS:
 *   FktNewRegEx    : pointer to dboxTV new regex function
 *   FktSetRegEx    : pointer to dboxTV set regex function
 *   FktGetMatch    : pointer to dboxTV get match regex function
 *   FktExecute     : pointer to dboxTV execute regex function
 *   FktExecuteNext : pointer to dboxTV execute next regex function
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function InitRegEx (FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext : Pointer):ByteBool; stdcall;
begin
  Result := true;

  try
    // create needed regex here
    if RegEx = nil then
      RegEx := TRegEx.Create(FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext, @FreePChar);
    if not Assigned(RegExChannels) then
      RegExChannels := TRegEx.Create(FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext, @FreePChar);
    if not Assigned(RegExServices) then
      RegExServices := TRegEx.Create(FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext, @FreePChar);

  except
    Result := false;
  end;
end;

(*******************************************************************************
 * INFO:
 *   free allocated memory, called by dboxTV on close
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function Close():ByteBool;stdcall;
begin
  Result := true;

  try
    // free objects
    if Assigned(RegEx) then
      RegEx.Free;

    if Assigned(RegExChannels) then
      RegExChannels.Free;

    if Assigned(RegExServices) then
      RegExServices.Free;

    if Assigned(HttpClient) then
      HttpClient.Free;

    RegEx := nil;
    RegExChannels := nil;
    RegExServices := nil;
    HttpClient := nil;

  except
    Result := false;
  end;
end;

(*******************************************************************************
 * INFO:
 *   check if DLL matches to the box
 *
 * RGW:
 *   Status : true = box is compatible with this dll
 ******************************************************************************)
function Check (BoxID : Integer):ByteBool; stdcall;
var
  sTime : ShortString;
  sSettings : ShortString;
begin
  Result := true;

  Log('dboxTV_neutrinohd.dll: Checking...', 0);

  // check time
  sTime := HttpClient.GetURL(BoxID, URL_DBOX_TIME);

  try
    StrToInt(sTime);
  except
    Result := false;
    exit;
  end;

  // now, we know this is a neutrino, but we have to check for neutrinoHD
  sSettings := HttpClient.GetURL(BoxID, URL_DBOX_SETTINGS);

  if not (sSettings = 'error') then
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   read box name
 *
 * RGW:
 *   Status : box name
 ******************************************************************************)
function GetBoxName():ShortString; stdcall;
begin
  Result := BOXNAME;
end;

(*******************************************************************************
 * INFO:
 *   read author name
 *
 * RGW:
 *   Status : author name
 ******************************************************************************)
function GetDLLAuthor():ShortString; stdcall;
begin
  Result := AUTHOR;
end;

(*******************************************************************************
 * INFO:
 *   read dll version
 *
 * RGW:
 *   Status : dll version
 ******************************************************************************)
function GetDLLVersion():ShortString; stdcall;
begin
  Result := VERSION;
end;

// ##############################################################################################
// ############################ box functions ###################################################
// ##############################################################################################

(*******************************************************************************
 * INFO:
 *   read current time -> URL_DBOX_TIME -> '1258846068'
 *
 * RGW:
 *   Status : time_t as string
 ******************************************************************************)
function GetTime(BoxID : Integer):ShortString; stdcall;
begin
  Result := HttpClient.GetURL(BoxID, URL_DBOX_TIME);
end;

(*******************************************************************************
 * INFO:
 *   read current record mode -> URL_DBOX_RECORDSTATUS -> 'on'/'off'
 *
 * RGW:
 *   Status : true = record running
 *            false = record off
 ******************************************************************************)
function GetRecordMode(BoxID : Integer):ByteBool; stdcall;
var
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RECORDSTATUS);

  if sTemp = 'on' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   read current spts mode -> URL_DBOX_SPTS -> '0'/'1'
 *
 * RGW:
 *   Status : '1' = spts mode is on
 *            '0' = spts mode is off
 ******************************************************************************)
function GetSPTSMode(BoxID : Integer):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS);

  if sTemp = '1' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   set current spts mode -> URL_DBOX_SPTS_ON/URL_DBOX_SPTS_OFF -> 'ok'
 *
 * RGW:
 *   Status : 'ok' = spts mode is set
 ******************************************************************************)
function SetSPTSMode(BoxID : Integer; OnOff : ByteBool):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  if OnOff then
    sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS_ON)
  else
    sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS_OFF);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   set a message to the tv screen -> URL_DBOX_MESSAGE -> 'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetMessageOnTv(BoxID : Integer; Msg : ShortString):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_MESSAGE, TAG_DATA, Msg);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   lock remote control -> URL_DBOX_RC_LOCK -> 'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetRCLock(BoxID : Integer):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RC_LOCK);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   unlock remote control -> URL_DBOX_RC_UNLOCK -> 'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetRCUnlock(BoxID : Integer):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RC_UNLOCK);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   read dbox mode -> URL_DBOX_GETMODE -> 'radio'/'tv'/'unknown'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function GetBoxMode(BoxID : Integer):ShortString; stdcall;
begin
  Result := HttpClient.GetURL(BoxID, URL_DBOX_GETMODE);
end;

(*******************************************************************************
 * INFO:
 *   set dbox mode -> URL_DBOX_SETMODE -> 'radio'/'tv'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetBoxMode(BoxID : Integer; Mode : ShortString):ByteBool; stdcall;
var
  sTemp : ShortString;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SETMODE, TAG_DATA, Mode);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   read stream info -> URL_DBOX_GETALLPIDS/URL_DBOX_STREAMINFO
 *
 *   URL_DBOX_GETALLPIDS
 *   -------------------
 * 00110
 * 00120 Mono
 * 00121 Mono
 * 00125 Dolby Digital 2.0
 * 00130 vtxt
 * 00100 pmt
 *
 *   VPID
 *    00511
 *   APID <description> [(AC3)]
 *    00512 deutsch
 *    00513 englisch
 *    00515 Dolby Digital 2.0
 *   [APID...]
 *   [VTXT PID]
 *    00032 vtxt
 *   PMT
 *    00101 pmt
 *
 *   URL_DBOX_STREAMINFO
 *   -------------------
 *   1280x720
 *   16:9
 *   50fps
 *   MPEG stereo (48000)
 *
 *   X/Y_res
 *     576x480
 *   VideoFormat
 *     4:3
 *   Framerate
 *     25
 *   AudioFormat
 *     joint stereo
 *
 * RGW:
 *   Status : RStreamInfo
 ******************************************************************************)
function GetStreamInfo (BoxID : Integer):RStreamInfo;  stdcall;
var
  i,c : Integer;
  sTmp : ShortString;
  MyStreamInfo : RStreamInfo;

  sPids : String;
  sStreamInfo : String;

  iMatchCount : Integer;
begin
  MyStreamInfo.sAPID := '';
  MyStreamInfo.sALANG := '';
  MyStreamInfo.iAPIDCnt := 0;

  // get stream pids
  sPids := HttpClient.GetURL(BoxID, URL_DBOX_GETALLPIDS);

  // ### extract stream info ###
  (*
    Text:
      00767
      00768 Deutsch
      00771 Dolby Digital 2.0
      00032 vtxt
      00102 pmt

    RegEx:
      (\d{5})\s(.*)

(*  Result:
      $0 [1 - 6]: 00767
      $1 [1 - 5]: 00767
      $2 [7 - 6]:
      $0 [8 - 20]: 00768 Deutsch
      $1 [8 - 12]: 00768
      $2 [14 - 20]: Deutsch
      $0 [23 - 45]: 00771 Dolby Digital 2.0
      $1 [23 - 27]: 00771
      $2 [29 - 45]: Dolby Digital 2.0
      $0 [48 - 57]: 00032 vtxt
      $1 [48 - 52]: 00032
      $2 [54 - 57]: vtxt
      $0 [60 - 68]: 00102 pmt
      $1 [60 - 64]: 00102
      $2 [66 - 68]: pmt
  *)
  RegEx.SetRegEx('(\d{5})\s(.*)', false);

  // execute regex
  iMatchCount := RegEx.Execute(PChar(sPids));

  // for each line (line count not known, so just loop long enough)
  for i:=0 to 20 do begin
    // VPID
    if i=0 then
      MyStreamInfo.sVPID := '0x'+IntToHex(StrToInt(RegEx.GetMatch(1)), 4)

    // PMT
    else if UpperCase(RegEx.GetMatch(2)) = UpperCase('pmt') then
      MyStreamInfo.sPMT := '0x'+IntToHex(StrToInt(RegEx.GetMatch(1)), 4)

    // VTXT
    else if UpperCase(RegEx.GetMatch(2)) = UpperCase('vtxt') then
      // not used
    else begin
      // APID <description> [(AC3)]
      for c:=0 to iMatchCount do begin
        case c of
          1: begin // APID
               sTmp := RegEx.GetMatch(c);
               MyStreamInfo.sAPID := MyStreamInfo.sAPID+'0x'+IntToHex(StrToInt(Trim(sTmp)),4);
             end;
          2: begin // Desc
               sTmp := RegEx.GetMatch(c);
               MyStreamInfo.sALANG := MyStreamInfo.sALANG+sTmp+',';
               MyStreamInfo.sAPID := MyStreamInfo.sAPID+ ',';

               Inc(MyStreamInfo.iAPIDCnt);
             end;
        end;
      end;
    end;

    // next regex result
    RegEx.ExecuteNext;
  end;

  // eliminate last sign
  Delete(MyStreamInfo.sAPID, Length(MyStreamInfo.sAPID), 1);
  Delete(MyStreamInfo.sALANG, Length(MyStreamInfo.sALANG), 1);

  // get stream info
  sStreamInfo := HttpClient.GetURL(BoxID, URL_DBOX_STREAMINFO);
  sStreamInfo := sStreamInfo+^M; // append carriage return due to parsing last line

  // ### extract stream info ###
  (*
    Text:
      720x576
      16:9
      25fps
      MPEG stereo (48000)

    RegEx:
      .*[\r]

    Result:
      $0 [1 - 4]: 480x576
      $0 [6 - 9]: 16:9
      $0 [11 - 17]: 50fps
      $0 [19 - 22]: MPEG stereo (48000)
  *)
  RegEx.SetRegEx('.*[\r]', false);

  // execute regex
  RegEx.Execute(PChar(sStreamInfo));

  MyStreamInfo.sResolution  := RegEx.GetMatch(0);
  RegEx.ExecuteNext; // next regex result
  MyStreamInfo.sAspectRatio := RegEx.GetMatch(0);
  RegEx.ExecuteNext; // next regex result
  MyStreamInfo.sFramerate   := RegEx.GetMatch(0);
  RegEx.ExecuteNext; // next regex result
  MyStreamInfo.sAudiotyp    := RegEx.GetMatch(0);
  MyStreamInfo.sBitrate     := '-';

  Result := MyStreamInfo;
end;

(*******************************************************************************
 * INFO:
 *   build stream url for HTTP and UDP mode
 *
 *   UDP = false, Mode = mTV
 *         http: *192.168.0.1:31339/0,0x002e,0x00a6,0x0080
 *                                  ->0x002e = 00046 pmt
 *                                  ->0x00A6 = 00166 vpid
 *                                  ->0x0080 = 00128 apid
 *   UDP = false, Mode = mRadio
 *         http: *192.168.0.1:31339/0,0x0080
 *                                  ->0x0080 = 00128 apid
 *
 *   UDP = true, Mode = mTV
 *         http: *192.168.0.1/control/exec?api udp_stream start 192.168.0.3 31330 0 0x002e 0x00a6 0x0080
 *                                  ->192.168.0.3 = IP
 *                                  ->31330 = Port
 *                                  ->0x002e = 00046 pmt
 *                                  ->0x00A6 = 00166 vpid
 *                                  ->0x0080 = 00128 apid
 *
 * PARAMS:
 *   AStreamInfo : current RStreamInfo from dboxTV
 *   IsUDP       : true = dbox streams in udp mode
 *                 false = dbox streams in http mode
 *   IsTV        : true = dbox is in tv mode
 *                 false = dbox is in radio mode
 *   IP          : pc ip, only for udp mode
 *   Port        : stream port, only for udp mode
 *
 * RGW:
 *   Status : stream url
 ******************************************************************************)
function GetStreamURL(BoxID : Integer; AStreamInfo:RStreamInfo; IsUDP : ByteBool; IsTV : ByteBool; PcIP, PcPort : ShortString):ShortString; stdcall;
var
  sURL : ShortString;
begin
  sURL := '';

  // http
  if not IsUDP then begin
    sURL := 'http://'+GetBoxData(BoxID).sIp+':31339/0,'+AStreamInfo.sPMT+','
                                                  +AStreamInfo.sVPID+',' ;
    // append audio pids
    sURL := sURL+AStreamInfo.sAPID;
  end
  else begin // udp
    sURL := 'http://'+GetBoxData(BoxID).sIp+':'+GetBoxData(BoxID).sPort+URL_DBOX_UDP_START+' '+PcIP+' '+PcPort+' 0 '
            +AStreamInfo.sPMT+' '
            +AStreamInfo.sVPID+' ';

    // append audio pids
    sURL := sURL+ReplSubStr(AStreamInfo.sAPID, ',', ' ');
  end;

  Result := sURL;
end;

(*******************************************************************************
 * INFO:
 *   call a rcem key for remote controlling -> URL_DBOX_RCEM -> 'ok'
 *   dboxTV sends neutrino KEY strings (e.g. 'KEY_HELP'), you may have to adapt
 *   this for other boxes/images -> have a look in UntDataDLL.pas
 *
 * PARAMS:
 *   Key : key name (e.g. 'KEY_HELP')
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetRCEMKey(BoxID : Integer; Key:ShortString):ByteBool;  stdcall;
var
  sTemp : String;
begin
  // take Key as it is
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RCEM, TAG_DATA, Key);
  Sleep(100); // wait
  
  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   zap to a channel -> URL_DBOX_ZAPTO_CHAN
 *
 * PARAMS:
 *   ChannelID           : channel id
 *   IsSubChannel        : true = channel is a subchannel
 *                         false = channel is a normal channel
 *   UseAltSubChannelZap : true = uses alternative zapping through rcem calls
 *   SubIndex            : current subchannel index
 *   SubCnt              : current subchannel count
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetZapChannel(BoxID : Integer; ChannelID : ShortString; IsSubChannel,UseAltSubChannelZap : ByteBool; SubIndex, SubCnt : Integer):ByteBool;  stdcall;
var
  i : Integer;
  sTemp : String;
begin

  // if no subchannel, or no alternative zap method
  if not IsSubChannel or not UseAltSubChannelZap then begin
    // zsp the normal way
    sTemp := HttpClient.GetURL(BoxID, URL_DBOX_ZAPTO_CHAN, TAG_DATA, ChannelID);
  end
  else begin
    // zap via rcem calls
    if UseAltSubChannelZap then begin
      if SubIndex < 10 then begin
        SetRCEMKey(BoxID, 'KEY_HELP');   // call ? will refresh subchannels
        SetRCEMKey(BoxID, 'KEY_YELLOW'); // call subchannel menu
        Sleep(500); // wait
        SetRCEMKey(BoxID, 'KEY_'+IntToStr(SubIndex)) // direct choose subchannel via subindex
      end
      else begin
        SetRCEMKey(BoxID, 'KEY_HELP');   // call ? will refresh subchannels
        SetRCEMKey(BoxID, 'KEY_YELLOW'); // call subchannel menu
        SetRCEMKey(BoxID, 'KEY_YELLOW'); // go down to menu bottom, will change mode
        SetRCEMKey(BoxID, 'KEY_YELLOW'); // set mode back
        for i := 1 to (SubCnt-1-SubIndex+1) do begin // go up to the wanted subchannel
          SetRCEMKey(BoxID, 'KEY_UP');
        end;
        SetRCEMKey(BoxID, 'KEY_OK');
      end;
    end;
  end;

  if sTemp = 'ok' then
    Result := true
  else
    Result := false
end;

(*******************************************************************************
 * INFO:
 *   read subchannels -> URL_DBOX_CHANNEL_SUBCHANS
 *
 * PARAMS:
 *   ChannelID : channel id, only for future use
 *
 * RGW:
 *   List (Text) : channel_id channel_name
 *                 channel_id channel_name
 *                 ...
 ******************************************************************************)
function GetSubChannels(BoxID : Integer; ChannelID : ShortString):PChar; stdcall;
begin
  Result := PChar(HttpClient.GetURL(BoxID, URL_DBOX_CHANNEL_SUBCHANS));
end;

(*******************************************************************************
 * INFO:
 *   stop udp stream -> URL_DBOX_UDP_STOP
 *
 * RGW:
 *   Status : true
 ******************************************************************************)
function SetUDPStreamStop(BoxID : Integer):ByteBool;  stdcall;
begin
  HttpClient.GetURL(BoxID, URL_DBOX_UDP_STOP);

  // TODO: check?

  Result := true;
end;

(*******************************************************************************
 * INFO:
 *   read current channel id -> URL_DBOX_ZAPTO
 *
 * RGW:
 *   channel id
 ******************************************************************************)
function GetCurrentChannelID(BoxID : Integer):ShortString;  stdcall;
begin
  Result := HttpClient.GetURL(BoxID, URL_DBOX_ZAPTO);
end;

(*******************************************************************************
 * INFO:
 *   box shutdown -> URL_DBOX_SHUTDOWN ->  'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetShutdown(BoxID : Integer):ByteBool;  stdcall;
var
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SHUTDOWN);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false
end;

(*******************************************************************************
 * INFO:
 *   box standby -> URL_DBOX_STANDBY ->  'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetStandby(BoxID : Integer):ByteBool;  stdcall;
var
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_STANDBY);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false
end;

(*******************************************************************************
 * INFO:
 *   box wakeup -> URL_DBOX_WAKEUP ->  'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetWakeUp(BoxID : Integer):ByteBool;  stdcall;
var
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_WAKEUP);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false
end;

(*******************************************************************************
 * INFO:
 *   box reboot -> URL_DBOX_REBOOT ->  'ok'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function SetReboot(BoxID : Integer):ByteBool;  stdcall;
var
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_REBOOT);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   get a osd screenshot-> URL_DBOX_OSDSHOT -> gets picture as bytstream
 *
 * RGW:
 *   buffer size
 ******************************************************************************)
function GetOSDShot(BoxID : Integer):Pointer; stdcall;
begin
  // take a screenshot
  SendTelnetCmd(BoxID, URL_DBOX_OSDSHOT_EXEC, 3000); // use dboxTV telnet cmd delay

  // get screenshot, binary data
  Result := HttpClient.GetURL_BIN(BoxID, URL_DBOX_OSDSHOT);
end;

(*******************************************************************************
 * INFO:
 *   read all bouquets
 *   -> use bouquets.xml and services.xml
 *   -> extract all channeldata from bouquets.xml (URL_DBOX_GETBOUQUETSXML)
 *   -> extract servicetyp (radio/tv) from services.xml (URL_DBOX_GETSERVICESXML)
 *
 * RGW:
 *   bouquet count
 ******************************************************************************)
function GetBouquets(BoxID : Integer):Integer; stdcall;
var
  iInxBouquet : Integer;     // bouquet index
  iInxChannel : Integer;     // channel index
  iInxChannelGlob : Integer; // global channel index
  Bouquet : RBouquet;        // bouquet
  Channel : RChannel;        // channel
  sTemp : String;            // temp. string
  APChar : PChar;            // temp. pchar

  Bouquets : TStringList;    // bouquet list
  Services : TStringList;    // services list
  sServiceList : String;     // temp service list
  IsBouquetAdded : Boolean;  // temp. flag to mark a bouquet as added
begin

  // init
  iInxBouquet := 0;
  iInxChannel := 0;
  iInxChannelGlob := 0;
  IsBouquetAdded := false;
  Bouquets := TStringList.Create;
  Services := TStringList.Create;
  sServiceList := '';
  sTemp := '';

try
  // read services
  Services.Text := HttpClient.GetURL(BoxID, URL_DBOX_GETSERVICESXML);

  // check for local bouquets.xml
  if FileExists('bouquets.xml') then begin
    Bouquets.LoadFromFile('bouquets.xml');
  end
  else
    // read bouquets
    Bouquets.Text := HttpClient.GetURL(BoxID, URL_DBOX_GETBOUQUETSXML);

  // ### extract bouquets ###
  (*
      Text:
        <Bouquet name="Favorites Movie" hidden="0" locked="0">
          <S i="002a" n="13th Street" t="0001" on="0085" s="192" frq="12070"/>
          <S i="0024" n="SciFi" t="0011" on="0085" s="192" frq="11758"/>
        </Bouquet>

      RegEx:
        <Bouquet name="(.*?)" hidden="(.*?)" locked="(.*?)">(.*?)</Bouquet>

      Result:
        $0 [1 - 242]: <Bouquet name="Favorites Movie" hidden="0" locked="0">
                       <S i="002a" n="13th Street" t="0001" on="0085" s="192" frq="12070"/>
                       <S i="0024" n="SciFi" t="0011" on="0085" s="192" frq="11758"/>
                    </Bouquet>
        $1 [16 - 30]: Favorites Movie
        $2 [41 - 41]: 0
        $3 [52 - 52]: 0
        $4 [55 - 232]:
                       <S i="002a" n="13th Street" t="0001" on="0085" s="192" frq="12070"/>
                       <S i="0024" n="SciFi" t="0011" on="0085" s="192" frq="11758"/>
  *)
  RegEx.SetRegEx('<Bouquet.*?name="(.*?)" '+
                          'hidden="(.*?)" '+
                          'locked="(.*?)">'+
                          '(.*?)'+ // all Channels!
                          '</Bouquet>',
                          true); // S = one line

  RegEx.Execute(PChar(Bouquets.Text));

  while (true) do begin
    // skip hidden bouquets
    if RegEx.GetMatch(2) = '1' then begin
      if (not RegEx.ExecuteNext) then
        break
      else
        continue;
    end;

    // set bouquet index
    Bouquet.Index := iInxBouquet;

    // extract and build bouquet name
    if (Bouquet.Index > 8) then begin
      Bouquet.Name := IntToStr(Bouquet.Index+1)+'. '+RegEx.GetMatch(1);
    end
    else begin
      Bouquet.Name := '0'+IntToStr(Bouquet.Index+1)+'. '+RegEx.GetMatch(1);
    end;

    // ### extract channel data ###
    (*
        Text:
          <S i="0009" n="Sky Action" t="0002" on="0085" s="192" frq="11798".*/>

        RegEx:
          <S i="(.*?)" n="(.*?)" t="(.*?)" on="(.*?)" s="(.*?)" frq="(.*?)"/>

        Result:
          $0 [1 - 67]: <S i="0009" n="Sky Action" t="0002" on="0085" s="192" frq="11798"/>
          $1 [7 - 10]: 0009
          $2 [16 - 25]: Sky Action
          $3 [31 - 34]: 0002
          $4 [41 - 44]: 0085
          $5 [50 - 52]: 192
          $6 [60 - 64]: 11798
    *)
    RegExChannels.SetRegEx('<S i="(.*?)" '+
                              'n="(.*?)" '+
                              't="(.*?)" '+
                              'on="(.*?)" '+
                              's="(.*?)" '+
                              'frq="(.*?)".*'+
                              '/>', // 'sat' or nothing, -> unimportant
                              false);

   APChar := StrAlloc(length(RegEx.GetMatch(4)) + 1);
   StrPCopy(APChar, RegEx.GetMatch(4));

   RegExChannels.Execute(APChar);

   StrDispose(APChar);

    while (true) do begin
      // check if there are channels
      if RegExChannels.GetMatch(2) = '' then
        break;

      // channel name
      Channel.sName := RegExChannels.GetMatch(2);

      // channel name?
      if Channel.sName = '' then begin
        if (not RegExChannels.ExecuteNext) then
          break;
      end;

      // set channel data
      if RegExChannels.GetMatch(0) <> '' then begin
        try

          // build channel id
          Channel.sChannelId := IntToHex(StrToInt(RegExChannels.GetMatch(6))*4+StrToInt(RegExChannels.GetMatch(5)), 4)+
                                IntToHex(StrToInt('$' + RegExChannels.GetMatch(3)), 4)+
                                IntToHex(StrToInt('$' + RegExChannels.GetMatch(4)), 4)+
                                IntToHex(StrToInt('$' + RegExChannels.GetMatch(1)), 4);

          Channel.sChannelId := LowerCase(Channel.sChannelId);

        except
        end;

        // set indizes
        Channel.BouquetIndex := iInxBouquet;
        Channel.Index := iInxChannel;
        Channel.IndexGlobal := iInxChannelGlob;
      end;

      // before parse services.xml cut all text until current transponder (really faster!)
      if (pos('TS id="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(3)), 4))+'"', Services.Text) > 0) then begin
        SplitString(Services.Text, 'TS id="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(3)), 4))+'"', sTemp, sServiceList)
      end
      else if (pos('TS id="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(3)), 4))+'"', Services.Text) > 0) then
        SplitString(Services.Text, 'TS id="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(3)), 4))+'"', sTemp, sServiceList);

      // not needed
      sTemp := '';

      // copy 200 characters up to current channel name for extracting service data (really faster!)
      sTemp := Copy(sServiceList, pos('n="'+RegExChannels.GetMatch(2)+'"', sServiceList)-15, 200);
       
      // ### extract service data ###
      (*
        $0 [7539 - 7595]: <S i="4f7d" n="MGM" t="1"/>
        $1 [7572 - 7574]: MGM
        $2 [7591 - 7592]: 1
          OR
        $2 [7591 - 7592]: 0001
      *)
      APChar := StrAlloc(length('<S i="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(1)), 4))+'" '+
                                   'n="(.*?)" '+
                                   't="(.*?)".*?') + 1);
      StrPCopy(APChar, '<S i="'+LowerCase(IntToHex(StrToInt('$' + RegExChannels.GetMatch(1)), 4))+'" '+
                                   'n="(.*?)" '+
                                   't="(.*?)".*?');

      RegExServices.SetRegEx(APChar, false);
      RegExServices.Execute(PChar(sTemp));

      StrDispose(APChar);

      // if nothing found, set tv mode as default (or ignore channel?)
      if RegExServices.GetMatch(0) = '' then begin
        Channel.Mode := true;
      end
      else begin
        try
          // mode, 2=radio
          if StrToInt(RegExServices.GetMatch(2)) = 2 then begin
            Channel.Mode := false; // radio
          end
          else begin
            Channel.Mode := true; // tv
          end;
        except
        end;
      end;

      // set channel name if not found already
      if (Channel.sName = '') then
        Channel.sName := RegExServices.GetMatch(1);

      // insert channel numbers and radio tag
      if (Channel.IndexGlobal > 8) then begin
        if not Channel.Mode then
          Channel.sName := IntToStr(Channel.IndexGlobal+1)+'. Radio: '+Channel.sName
        else
          Channel.sName := IntToStr(Channel.IndexGlobal+1)+'. '+Channel.sName
      end
      else begin
        if not Channel.Mode then
          Channel.sName := '0'+IntToStr(Channel.IndexGlobal+1)+'. Radio: '+Channel.sName
        else
          Channel.sName := '0'+IntToStr(Channel.IndexGlobal+1)+'. '+Channel.sName;
      end;

      // add bouquet once
      if not IsBouquetAdded then begin
        AddBouquet(BoxID, Bouquet);
        IsBouquetAdded := true;
      end;

      // add channel to bouquet
      AddChannel(BoxID, Bouquet.Index, Channel);

      // increase indizes and go to add next channel
      Inc(iInxChannel);
      Inc(iInxChannelGlob);

      if (not RegExChannels.ExecuteNext) then
        break;
    end; // END WHILE channel loop

    // increase bouquet index if at least one channel exists in bouquet
    if iInxChannel <> 0 then begin
      Inc(iInxBouquet);
      IsBouquetAdded := false;
    end;

    // reset channel index and go to add next bouquet
    iInxChannel := 0;
    if (not RegEx.ExecuteNext) then
      break;

  end; // END WHILE bouquet loop

  // return bouquet index
  Result := iInxBouquet;

finally

  Bouquets.Free;
  Services.Free;
end;

end;

(*******************************************************************************
 * INFO:
 *   read a list of all channels with current program data, used in a thread
 *   -> URL_DBOX_EPGEXT
 *   dboxTV will call this first before GetEPGChannel() to show all available
 *   current programs for all channels at once!
 *
 *   format: channelid  starttime duration      eventid        title
 *          44d00016dca 1258819380 1620 309903955495372998 ARD-Ratgeber: Technik
 *          43700016d66 1258819500 2400 303711506001195607 Länderspiegel
 *
 * RGW:
 *   List (Text) -> format
 ******************************************************************************)
function GetEPGCurrentChannels(BoxID : Integer): PChar; stdcall;
begin
  Result := HttpClient.GetURL_EPG(BoxID, URL_DBOX_EPGEXT);
end;

(*****************************************************************************
 * INFO:
 *   read all channel programs of a channel, used in a thread -> URL_DBOX_EPGPROGRAMS
 *
 * PARAMS:
 *   ChannelID    : channel id
 *   BouquetIndex : bouquet index
 *   ChannelIndex : channel index
 *
 * RGW:
 *   channel program count
 ******************************************************************************)
function GetEPGChannel(BoxID : Integer; ChannelID : ShortString; BouquetIndex : Integer; ChannelIndex : Integer):Integer; stdcall;
var
  i,Counter : Integer;
  ChannelProgram : RChannelProgram;

  sEPGData : String;
  APChar : PChar;
begin
  // init
  Counter := 0;

  // read channel programs
  sEPGData := HttpClient.GetURL_EPG(BoxID, URL_DBOX_EPGPROGRAMS, TAG_DATA, ChannelID);

  // ### extract epg info ###
  (*
    Text:
      <prog>
        <bouquetnr>0</bouquetnr>
        <channel_id>bf30044100012ee3</channel_id>
        <eventid>306526254719500558</eventid>
        <eventid_hex>44100012ee3010e</eventid_hex>
        <start_sec>1280563200</start_sec>
        <start_t>10:00</start_t>
        <date>31.07.2010</date>
        <stop_sec>1280572200</stop_sec>
        <stop_t>12:30</stop_t>
        <duration_min>150</duration_min>
        <description>Gute Zeiten, schlechte Zeiten</description>
        <info1></info1>
        <info2>- Wiederholung der Folgen 4535 - 4539 -</info2>
      </prog>

    RegEx:
      <prog>.*?<eventid>(.*?)</eventid>.*?<eventid_hex>(.*?)</eventid_hex>
      .*?<start_sec>(.*?)</start_sec>.*?<start_t>(.*?)</start_t>
      .*?<stop_sec>(.*?)</stop_sec>.*?<stop_t>(.*?)</stop_t>
      .*?<duration_min>(.*?)</duration_min>
      .*?<description><!\[CDATA\[(.*?)\]\]></description>
      .*?<info1><!\[CDATA\[(.*?)\]\]></info1>
      .*?<info2><!\[CDATA\[(.*?)\]\]></info2>
      .*?</prog>

    Result:
      $0 [1 - 528]: <prog>
              <bouquetnr>0</bouquetnr>
              <channel_id>bf30044100012ee3</channel_id>
              <eventid>306526254719500558</eventid>

              <eventid_hex>44100012ee3010e</eventid_hex>
              <start_sec>1280563200</start_sec>
              <start_t>10:00</start_t>
              <date>31.07.2010</date>
              <stop_sec>1280572200</stop_sec>
              <stop_t>12:30</stop_t>

              <duration_min>150</duration_min>
              <description><![CDATA[Gute Zeiten, schlechte Zeiten]]></description>
              <info1><![CDATA[]]></info1>
              <info2><![CDATA[- Wiederholung der Folgen 4535 - 4539 -]]></info2>
      </prog>
      $1 [90 - 107]: 306526254719500558
      $2 [136 - 150]: 44100012ee3010e
      $3 [179 - 188]: 1280563200
      $4 [213 - 217]: 10:00
      $5 [267 - 276]: 1280572200
      $6 [299 - 303]: 12:30
      $7 [332 - 334]: 150
      $8 [375 - 403]: Gute Zeiten, schlechte Zeiten
      $9 [440 - 439]:
      $10 [470 - 508]: - Wiederholung der Folgen 4535 - 4539 -
  *)
  RegEx.SetRegEx('<prog>.*?<eventid>(.*?)</eventid>.*?'+
                            '<eventid_hex>(.*?)</eventid_hex>.*?'+
                            '<start_sec>(.*?)</start_sec>.*?'+
                            '<start_t>(.*?)</start_t>.*?'+
                            '<stop_sec>(.*?)</stop_sec>.*?'+
                            '<stop_t>(.*?)</stop_t>.*?'+
                            '<duration_min>(.*?)</duration_min>.*?'+
                            '<description><!\[CDATA\[(.*?)\]\]></description>.*?'+
                            '<info1><!\[CDATA\[(.*?)\]\]></info1>.*?'+
                            '<info2><!\[CDATA\[(.*?)\]\]></info2>.*?'+
                            '</prog>',
                            true); // S = one line

  RegEx.Execute(PChar(sEPGData));

  while (true) and (RegEx.GetMatch(0)<>'') do begin

    ChannelProgram.sChannelId := ChannelID;

    try
      // extract program info
      ChannelProgram.sEventId   := RegEx.GetMatch(1);
      ChannelProgram.sDuration  := RegEx.GetMatch(7);
      ChannelProgram.sStartSec  := RegEx.GetMatch(3);
      ChannelProgram.sStartTime := RegEx.GetMatch(4);
      ChannelProgram.sTitle     := RegEx.GetMatch(8);
      ChannelProgram.sTitle     := ReplSubStr(ChannelProgram.sTitle, ''#$B'', ''); // don't know the reason anymore
      ChannelProgram.sInfo1     := RegEx.GetMatch(9);
      if ChannelProgram.sInfo1 = '' then
        ChannelProgram.sInfo1 := '-';

      APChar := StrAlloc(length(RegEx.GetMatch(10)) + 1);
      StrPCopy(APChar, RegEx.GetMatch(10));

      ChannelProgram.sInfo2 := StrNew(APChar);
    except
    end;

    // add channel program to a channel
    i := AddChannelProgram(BoxID, BouquetIndex, ChannelIndex, ChannelProgram);

    // free sInfo2 data after add!
    StrDispose(APChar);
    StrDispose(ChannelProgram.sInfo2);

    if (i=1) then
      Inc(Counter);

    if (not RegEx.ExecuteNext) then
      break;
  end; // END WHILE channel program loop

  Result := Counter;
end;

// ##############################################################################################
// ################################### export functions #########################################
// ##############################################################################################

exports
  Init,
  InitHttp,
  InitRegEx,
  Close,
  Check,

  GetBoxName,
  GetDLLAuthor,
  GetDLLVersion,

  GetTime,
  GetRecordMode,
  GetSPTSMode,
  SetSPTSMode,
  SetMessageOnTv,
  SetRCLock,
  SetRCUnlock,
  GetBoxMode,
  SetBoxMode,
  GetStreamInfo,
  GetStreamURL,
  SetUDPStreamStop,
  SetZapChannel,
  GetSubChannels,
  SetRCEMKey,
  GetCurrentChannelID,
  SetShutdown,
  SetStandby,
  SetWakeUp,
  SetReboot,
  GetOSDShot,
  GetBouquets,
  GetEPGCurrentChannels,
  GetEPGChannel
  ;

begin
end.
