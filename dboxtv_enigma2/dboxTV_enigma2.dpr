// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       dboxTV_enigma2.dll - a box interface dll for dboxTV
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
// Info: This DLL enables the communication between dboxTV and Enigma2 (VU+).
//       It may be used as a template for other box interfaces.
//       This DLL provides functionality for the current selected box in dboxTV!
//       All transfered data types are compatible with other languages, so you
//       don't have to use delphi and this code! All functions use stdcall!
//
//       data flow:  dboxTV -> DLL -> box webinterface -> dboxTV
//
//       -> e.g. dboxTV wants the current channel id
//          1. dboxTV calls the DLL function GetCurrentChannelID()
//          2. DLL function calls GetURL(URL_DBOX_ZAPTO) and returns the data to dboxTV
//          3. dboxTV uses the data in context
//
//       All functions were created in relationship to Enigma2 so there
//       is a high possibility to miss a function or parameter which is needed for
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
//       Have a look at UntHttpClient.pas header to understand how you can
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
//       Plz have a look at UntRegEx.pas header info to understand how TRegExpr
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
// Files:    -dboxTV_enigma2.dpr    -> all dll functions and export
//           -UntURL.pas            -> box specific urls
//           -UntHelpers.pas        -> useful string handling functions
//           -UntHttpClient.pas     -> http request handling using dboxTV functions
//           -UntRegEx.pas          -> regex handling using dboxTV functions
//           -UntDataDLL.pas        -> data structures/function pointers for exchange
//                                     with dboxTV
//
// ##############################################################################################

library dboxtv_enigma2;

uses
  sysutils,
  windows,
  classes,
  UntURL in 'UntURL.pas',
  UntDataDLL in '..\UntDataDLL.pas',
  UntHelpers in '..\UntHelpers.pas',
  UntHttpClient in '..\UntHttpClient.pas',
  UntRegEx in '..\UntRegEx.pas';

{$IFDEF WINDOWS}{$R dboxTV_enigma2.rc}{$ENDIF}
{$LongStrings ON}

{$R *.RES}

// ##############################################################################################
// ################################### info #####################################################
// ##############################################################################################
const
  AUTHOR  = 'DsChAeK';        // author info for dboxtv about box
  VERSION = 'v1.0';           // version info for dboxtv about box
  BOXNAME = 'VU+ Enigma2';    // boxname info for dboxtv display

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
  sTime : String;
begin
  Result := true;

  Log('dboxTV_enigma2.dll: Checking...', 0);

  // get time
  sTime := HttpClient.GetURL(BoxID, URL_DBOX_TIME);

  // check if time is available
  if Pos('e2currenttime', sTime) <= 0 then
    Result := false
  else begin
    Result := true;
  end;
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
var
  Data : String;
  Time : cardinal;
begin
  Data := HttpClient.GetURL(BoxID, URL_DBOX_TIME);

  // ### extract bouquets ###
  (*
      Text:
        <?xml version="1.0" encoding="UTF-8"?>
        <e2currenttime>
                13:57:16
        </e2currenttime>


      RegEx:
        <e2currenttime>(.*?)</e2currenttime>

      Result:
        $0 [1 - 85]: <?xml version="1.0" encoding="UTF-8"?>
        <e2currenttime>
                13:53:03
        </e2currenttime>
        $1 [56 - 69]:
                13:53:03
  *)

  try
    RegEx.SetRegEx('<e2currenttime>(.*?)</e2currenttime>', true); // S = one line
    RegEx.Execute(PChar(Data));

    // get current date
    Data := FormatDateTime('d.m.yyyy', now);

    // catch time from box as string and trim
    Data := Data + ' ' + Trim(RegEx.GetMatch(1));

    // convert string from datetime to unix time
    Time := DateTimeToUnix(StrToDateTime(Data));
    
    // convert datetime to string
    Result := IntToStr(Time);
  except
    Result := '0';
  end;
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
(*  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RECORDSTATUS);

  if sTemp = 'on' then
    Result := true
  else
    Result := false;
    *)
  Result := true;
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
  sTemp : String;
begin
  (*sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS);

  if sTemp = '1' then
    Result := true
  else
    Result := false;
*)
  Result := true;
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
  sTemp : String;
begin
(*
  if OnOff then
    sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS_ON)
  else
    sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SPTS_OFF);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
    *)
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
  sTemp : String;
begin
  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_MESSAGE, TAG_DATA, Msg);

  if Pos('Message sent successfully', sTemp) > 0 then
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
  sTemp : String;
begin
(*  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RC_LOCK);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
    *)
  Result := true;  
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
  sTemp : String;
begin
(*  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_RC_UNLOCK);

  if sTemp = 'ok' then
    Result := true
  else
    Result := false;
    *)
  Result := true;    
end;

(*******************************************************************************
 * INFO:
 *   read dbox mode -> URL_DBOX_GETMODE -> 'radio'/'tv'/'unknown'
 *
 * RGW:
 *   Status : true = ok
 ******************************************************************************)
function GetBoxMode(BoxID : Integer):ShortString; stdcall;
var
  Data : String;
begin

  Data := HttpClient.GetURL(BoxID, URL_DBOX_GETMODE);

  // ### extract box mode ###
  (*
      Text:
        <?xml version="1.0" encoding="UTF-8"?>
        <e2currentserviceinformation>
                <e2service>
                        <e2servicereference>1:0:2:215C:400:1:C00000:0:0:0:</e2servicereference>
                        <e2servicename>FUN RADIO</e2servicename>
                        <e2providername>CSAT</e2providername>
                        <e2videowidth>N/A</e2videowidth>
                        <e2videoheight>N/A</e2videoheight>
                        <e2servicevideosize>N/AxN/A</e2servicevideosize>
                        <e2iswidescreen>
        0		</e2iswidescreen>
                        <e2apid>240</e2apid>
                        <e2vpid>N/A</e2vpid>
        ...
        
      RegEx:
        <e2vpid>(.*?)</e2vpid>

      Result:
        $0 [1 - 459]: <?xml version="1.0" encoding="UTF-8"?>
        <e2currentserviceinformation>
                <e2service>
                        <e2servicereference>1:0:2:215C:400:1:C00000:0:0:0:</e2servicereference>
                        <e2servicename>FUN RADIO</e2servicename>
                        <e2providername>CSAT</e2providername>
                        <e2videowidth>N/A</e2videowidth>
                        <e2videoheight>N/A</e2videoheight>
                        <e2servicevideosize>N/AxN/A</e2servicevideosize>
                        <e2iswidescreen>
        0		</e2iswidescreen>
                        <e2apid>240</e2apid>
                        <e2vpid>N/A</e2vpid>
        $1 [448 - 450]: N/A
  *)
  try
    RegEx.SetRegEx('<e2vpid>(.*?)</e2vpid>', true); // S = one line
    RegEx.Execute(PChar(Data));

    // catch time as string and trim
    Data := Trim(RegEx.GetMatch(1));

    if (Data = 'N/A') then begin
      Result := 'radio';
    end
    else
    begin
      Result := 'tv'
    end;
  except
    Result := 'unknown';
  end;

  Result := 'tv';
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
  sTemp : String;
begin
  if Mode = 'tv' then begin
    Mode := '377';
  end
  else if Mode = 'radio' then begin
    Mode := '385';
  end;

  sTemp := HttpClient.GetURL(BoxID, URL_DBOX_SETMODE, TAG_DATA, Mode);

  if pos('<e2result>True', sTemp) > 0 then
    Result := true
  else
    Result := false;
end;

(*******************************************************************************
 * INFO:
 *   read stream info -> URL_DBOX_GETALLPIDS/URL_DBOX_STREAMINFO
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

  sAudioPids : String;
  sStreamInfo : String;
  sAudioTrack : String;
  iMatchCount : Integer;
begin
  MyStreamInfo.sAPID := '';
  MyStreamInfo.sALANG := '';
  MyStreamInfo.iAPIDCnt := 0;

  // get stream pids
  sStreamInfo := HttpClient.GetURL(BoxID, URL_DBOX_STREAMINFO);

  // ### extract stream info ###
  (*
    Text:
      <?xml version="1.0" encoding="UTF-8"?>
      <e2currentserviceinformation>
              <e2service>
		<e2servicereference>1:0:19:2B8E:3F2:1:C00000:0:0:0:</e2servicereference>
		<e2servicename>3sat HD</e2servicename>
		<e2providername>ZDFvision</e2providername>
		<e2videowidth>1280</e2videowidth>
		<e2videoheight>720</e2videoheight>
		<e2servicevideosize>1280x720</e2servicevideosize>
		<e2iswidescreen>
1		</e2iswidescreen>
		<e2apid>6520</e2apid>
		<e2vpid>6510</e2vpid>
		<e2pcrpid>6510</e2pcrpid>
		<e2pmtpid>6500</e2pmtpid>
		<e2txtpid>6530</e2txtpid>
		<e2tsid>1010</e2tsid>
		<e2onid>1</e2onid>
		<e2sid>11150</e2sid>
                ...

    RegEx:
      .*?<e2servicereference>(.*?)</e2servicereference>
      .*?<e2servicevideosize>(.*?)</e2servicevideosize>

    Result:
      $1 [133 - 163]: 1:0:19:2B8E:3F2:1:C00000:0:0:0:
      $2 [372 - 379]: 1280x720

  *)
  RegEx.SetRegEx('.*?<e2servicereference>(.*?)</e2servicereference>'+
                 '.*?<e2servicevideosize>(.*?)</e2servicevideosize>'
                 , true);

  // execute regex
  RegEx.Execute(PChar(sStreamInfo));

  MyStreamInfo.sVPID := RegEx.GetMatch(1);
  MyStreamInfo.sResolution := RegEx.GetMatch(2);

  // get all audio pids
  sAudioPids := HttpClient.GetURL(BoxID, URL_DBOX_GETALLPIDS);

  // ### extract audio pids ###
  (*
    Text:
      <?xml version="1.0" encoding="UTF-8"?>
      <e2audiotracklist>
                      <e2audiotrack>
                              <e2audiotrackdescription>MPEG (Stereo)</e2audiotrackdescription>
                              <e2audiotrackid>0</e2audiotrackid>
                              <e2audiotrackpid>6520</e2audiotrackpid>
                              <e2audiotrackactive>False</e2audiotrackactive>
                      </e2audiotrack>
                      <e2audiotrack>
                              <e2audiotrackdescription>MPEG (ohne Audiodeskription)</e2audiotrackdescription>
                              <e2audiotrackid>1</e2audiotrackid>
                              <e2audiotrackpid>6521</e2audiotrackpid>
                              <e2audiotrackactive>False</e2audiotrackactive>
                      </e2audiotrack>
                      <e2audiotrack>
                              <e2audiotrackdescription>Dolby Digital (Dolby Digital 2.0)</e2audiotrackdescription>
                              <e2audiotrackid>2</e2audiotrackid>
                              <e2audiotrackpid>6522</e2audiotrackpid>
                              <e2audiotrackactive>True</e2audiotrackactive>
                      </e2audiotrack>
                      <e2audiotrack>
                              <e2audiotrackdescription>MPEG (ohne Originalton)</e2audiotrackdescription>
                              <e2audiotrackid>3</e2audiotrackid>
                              <e2audiotrackpid>6523</e2audiotrackpid>
                              <e2audiotrackactive>False</e2audiotrackactive>
                      </e2audiotrack>
      </e2audiotracklist>


    RegEx:
      .*?<e2audiotrackdescription>(.*?)</e2audiotrackdescription>
      .*?<e2audiotrackid>(.*?)</e2audiotrackid>
      .*?<e2audiotrackpid>(.*?)</e2audiotrackpid>
      .*?<e2audiotrackactive>(.*?)</e2audiotrackactive>

    Result:
      $0 [1 - 281]: <?xml version="1.0" encoding="UTF-8"?>
      <e2audiotracklist>
                      <e2audiotrack>
                              <e2audiotrackdescription>MPEG (Stereo)</e2audiotrackdescription>
                              <e2audiotrackid>0</e2audiotrackid>
                              <e2audiotrackpid>6520</e2audiotrackpid>
                              <e2audiotrackactive>False</e2audiotrackactive>

      $1 [107 - 119]: MPEG (Stereo)
      $2 [167 - 167]: 0
      $3 [207 - 210]: 6520
      $4 [254 - 258]: False
  *)
  RegEx.SetRegEx('.*?<e2audiotrackdescription>(.*?)</e2audiotrackdescription>'+
                 '.*?<e2audiotrackid>(.*?)</e2audiotrackid>'+
                 '.*?<e2audiotrackpid>(.*?)</e2audiotrackpid>'+
                 '.*?<e2audiotrackactive>(.*?)</e2audiotrackactive>', true);

  // execute regex
  RegEx.Execute(PChar(sAudioPids));

  while (true) do begin
    MyStreamInfo.iAPIDCnt := MyStreamInfo.iAPIDCnt + 1;
    MyStreamInfo.sALANG := MyStreamInfo.sALANG + RegEx.GetMatch(1) + ',';
    MyStreamInfo.sAPID := MyStreamInfo.sAPID + RegEx.GetMatch(3) + ',';

    if (RegEx.ExecuteNext() = false) then begin
      break;
    end;
  end;

  MyStreamInfo.sAspectRatio := '16:9';
  MyStreamInfo.sFramerate := '25';
  MyStreamInfo.sAudiotyp := 'stereo';
  MyStreamInfo.sBitrate := '?';

  Result := MyStreamInfo;
end;

(*******************************************************************************
 * INFO:
 *   build stream url for HTTP and UDP mode
 *
 *   UDP = http://192.168.0.111:8001/1:0:19:2B8E:3F2:1:C00000:0:0:0:
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
  sURL := 'http://'+GetBoxData(BoxID).sIp+':8001/'+AStreamInfo.sVPID;

  Result := sURL;
end;

(*******************************************************************************
 * INFO:
 *   call a rcem key for remote controlling -> URL_DBOX_RCEM -> 'ok'
 *   dboxTV sends enigma2 KEY strings (e.g. 'KEY_HELP'), you may have to adapt
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
    (*
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
    *)
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
  Result := '';//HttpClient.GetURL(BoxID, URL_DBOX_CHANNEL_SUBCHANS);
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
  //HttpClient.GetURL(BoxID, URL_DBOX_UDP_STOP);

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
var
  sData : String;
begin
  sData := HttpClient.GetURL(BoxID, URL_DBOX_ZAPTO);

   // ### extract current channel id ###
  (*
      Text:
         ...
	<e2service>
		<e2servicereference>1:0:19:2B8E:3F2:1:C00000:0:0:0:</e2servicereference>
		<e2servicename>3sat HD</e2servicename>
		<e2providername>ZDFvision</e2providername>
		<e2videowidth>1280</e2videowidth>
		<e2videoheight>720</e2videoheight>
		<e2servicevideosize>1280x720</e2servicevideosize>
		<e2iswidescreen>
1		</e2iswidescreen>
		<e2apid>6520</e2apid>
		<e2vpid>6510</e2vpid>
		<e2pcrpid>6510</e2pcrpid>
		<e2pmtpid>6500</e2pmtpid>
		<e2txtpid>6530</e2txtpid>
		<e2tsid>1010</e2tsid>
		<e2onid>1</e2onid>
		<e2sid>11150</e2sid>
	</e2service>
        ...
        
      RegEx:
        <e2servicereference>(.*?)</e2servicereference>

      Result:
        $0 [17 - 88]: <e2servicereference>1:0:19:2B8E:3F2:1:C00000:0:0:0:</e2servicereference>
        $1 [37 - 67]: 1:0:19:2B8E:3F2:1:C00000:0:0:0:

  *)
  RegEx.SetRegEx('<e2servicereference>(.*?)</e2servicereference>', true); // S = one line
  RegEx.Execute(PChar(sData));

  Result := Trim(RegEx.GetMatch(1));
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

  Result := true
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

  Result := true
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

  Result := true
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

  Result := true
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
  //SendTelnetCmd(BoxID, URL_DBOX_OSDSHOT_EXEC, 3000); // use dboxTV telnet cmd delay

  // get screenshot, binary data
  //Result := HttpClient.GetURL_BIN(BoxID, URL_DBOX_OSDSHOT);
end;

(*******************************************************************************
 * INFO:
 *   read all bouquets
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
	<e2bouquet>
          <e2servicereference>1:7:1:0:0:0:0:0:0:0:FROM BOUQUET "userbouquet.favourites.tv" ORDER BY bouquet</e2servicereference>
          <e2servicename>Favourites (TV)</e2servicename>
          <e2servicelist>
            <e2service>
                    <e2servicereference>1:0:19:283D:3FB:1:C00000:0:0:0:</e2servicereference>
                    <e2servicename>Das Erste HD</e2servicename>
            </e2service>
            <e2service>
                    <e2servicereference>1:0:19:2B66:3F3:1:C00000:0:0:0:</e2servicereference>
                    <e2servicename>ZDF HD</e2servicename>
            </e2service>
          </e2servicelist>
        </e2bouquet>
        ...

      RegEx:
        <e2bouquet>(.*?<e2servicename>(.*?)</e2servicename>.*?)</e2bouquet>.*?

      Result:
        $1 [80 - 612]:
			<e2servicereference>1:7:1:0:0:0:0:0:0:0:FROM BOUQUET "userbouquet.favourites.tv" ORDER BY bouquet</e2servicereference>
			<e2servicename>Favourites (TV)</e2servicename>
			<e2servicelist>
			<e2service>
				<e2servicereference>1:0:19:283D:3FB:1:C00000:0:0:0:</e2servicereference>
				<e2servicename>Das Erste HD</e2servicename>
			</e2service>
			<e2service>
				<e2servicereference>1:0:19:2B66:3F3:1:C00000:0:0:0:</e2servicereference>
				<e2servicename>ZDF HD</e2servicename>
			</e2service>
			</e2servicelist>
		
        $2 [223 - 237]: Favourites (TV)
  *)
  RegEx.SetRegEx('<e2bouquet>(.*?<e2servicename>(.*?)</e2servicename>.*?)</e2bouquet>.*?', true); // S = one line

  RegEx.Execute(PChar(Bouquets.Text));

  while (true) do begin
    // set bouquet index
    Bouquet.Index := iInxBouquet;

    // extract and build bouquet name
    if (Bouquet.Index > 8) then begin
      Bouquet.Name := IntToStr(Bouquet.Index+1)+'. '+RegEx.GetMatch(2);
    end
    else begin
      Bouquet.Name := '0'+IntToStr(Bouquet.Index+1)+'. '+RegEx.GetMatch(2);
    end;

    // ### extract channel data ###
    (*
        Text:
                <e2servicereference>1:7:1:0:0:0:0:0:0:0:FROM BOUQUET "userbouquet.favourites.tv" ORDER BY bouquet</e2servicereference>
                <e2servicename>Favourites (TV)</e2servicename>
                <e2servicelist>
                <e2service>
                        <e2servicereference>1:0:19:283D:3FB:1:C00000:0:0:0:</e2servicereference>
                        <e2servicename>Das Erste HD</e2servicename>
                </e2service>
                <e2service>
                        <e2servicereference>1:0:19:2B66:3F3:1:C00000:0:0:0:</e2servicereference>
                        <e2servicename>ZDF HD</e2servicename>
                </e2service>
           	<e2service>
                        <e2servicereference>1:134:1:0:0:0:0:0:0:0:FROM BOUQUET "alternatives.zdf_neo_hd.tv" ORDER BY bouquet</e2servicereference>
                        <e2servicename>zdf_neo HD</e2servicename>
                </e2service>
                </e2servicelist>

        RegEx:
          <e2service>.*?<e2servicereference>(.*?)</e2servicereference>.*?<e2servicename>(.*?)</e2servicename>

        Result:
          $1 [235 - 265]: 1:0:19:283D:3FB:1:C00000:0:0:0:
          $2 [308 - 319]: Das Erste HD

    *)
   RegExChannels.SetRegEx('<e2service>.*?<e2servicereference>(.*?)</e2servicereference>.*?<e2servicename>(.*?)</e2servicename>', true);

   APChar := StrAlloc(length(RegEx.GetMatch(1)) + 1);
   StrPCopy(APChar, RegEx.GetMatch(1));

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
          Channel.sChannelId := RegExChannels.GetMatch(1);

          if (Pos('FROM BOUQUET "', Channel.sChannelId) > 0) then begin
            Channel.sChannelId := Copy(Channel.sChannelId, 0, Pos('FROM BOUQUET "', Channel.sChannelId)-1);
          end;
        except
        end;

        // set indizes
        Channel.BouquetIndex := iInxBouquet;
        Channel.Index := iInxChannel;
        Channel.IndexGlobal := iInxChannelGlob;
        Channel.Mode := true;
      end;

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
function GetEPGCurrentChannels(BoxID : Integer; ChannelID : ShortString): PChar; stdcall;
var
  sData : String;
  sConvertedData : String;
  APChar : PChar;  
begin
  sData := HttpClient.GetURL_EPG(BoxID, URL_DBOX_EPGEXT, TAG_DATA, ChannelID);

  // Prepare EPG data for dboxTV
  (*
      Text:
        ...
          <e2event>
                          <e2eventid>12631</e2eventid>
                          <e2eventstart>1402941600</e2eventstart>
                          <e2eventduration>3600</e2eventduration>
                          <e2eventcurrenttime>1402943010</e2eventcurrenttime>
                          <e2eventtitle>Mocca</e2eventtitle>
                          <e2eventdescription></e2eventdescription>
                          <e2eventdescriptionextended>Moderator: Andrea Rubio Sanchez
          Produkte der Show:
          3616089 - MOCCA Zauberhose Cora
          3616288 - MOCCA Top
          3616507 - MOCCA Shirt
          3617003 - MOCCA Shirt
          3616652 - MOCCA Shirt
          </e2eventdescriptionextended>
		<e2eventservicereference>1:0:1:301:7:85:C00000:0:0:0:</e2eventservicereference>
		<e2eventservicename>Channel21</e2eventservicename>
          </e2event>
        ...

      RegEx:
        <e2eventid>(.*?)</e2eventid>
        .*?<e2eventstart>(.*?)</e2eventstart>
        .*?<e2eventduration>(.*?)</e2eventduration>
        .*?<e2eventtitle>(.*?)</e2eventtitle>
        .*?<e2eventservicereference>(.*?)</e2eventservicereference>
        .*?</e2event>

      Result:
        $1 [81 - 85]: 12631
        $2 [116 - 125]: 1402941600
        $3 [162 - 165]: 3600
        $4 [257 - 261]: Mocca
        $5 [588 - 615]: 1:0:1:301:7:85:C00000:0:0:0:
  *)
  RegEx.SetRegEx('<e2eventid>(.*?)</e2eventid>' +
                 '.*?<e2eventstart>(.*?)</e2eventstart>' +
                 '.*?<e2eventduration>(.*?)</e2eventduration>' +
                 '.*?<e2eventtitle>(.*?)</e2eventtitle>' +
                 '.*?<e2eventservicereference>(.*?)</e2eventservicereference>' +
                 '.*?</e2event>', true); // S = one line

  RegEx.Execute(PChar(sData));

  while (true) do begin

    //  channelid  starttime duration      eventid        title
    sConvertedData := sConvertedData + RegEx.GetMatch(5) + ' ' + RegEx.GetMatch(2)+' '+RegEx.GetMatch(3)+' '+RegEx.GetMatch(1)+' '+RegEx.GetMatch(4)+#10#13;

    if (RegEx.ExecuteNext()) = false then begin
      break;
    end;
  end;

  APChar := StrAlloc(length(sConvertedData) + 1);
  StrPCopy(APChar, sConvertedData);

  Result := StrNew(APChar);

  // free data after add!
  StrDispose(APChar);
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
  APChar := nil;

  // read channel programs
  sEPGData := HttpClient.GetURL_EPG(BoxID, URL_DBOX_EPGPROGRAMS, TAG_DATA, ChannelID);

  // ### extract epg info ###
  (*
    Text:
        ...
	<e2event>
		<e2eventid>22435</e2eventid>
		<e2eventstart>1402942500</e2eventstart>
		<e2eventduration>5700</e2eventduration>
		<e2eventcurrenttime>1402944714</e2eventcurrenttime>
		<e2eventtitle>FIFA WM 2014: Iran - Nigeria</e2eventtitle>
		<e2eventdescription>Vorrunde Gruppe F (live, 1. Halbzeit)</e2eventdescription>
		<e2eventdescriptionextended>* Übertragung aus Curitiba ab 21.00 Uhr?* Reporter: Steffen Simon?* Experte: Mehmet Scholl?* Moderation: Matthias Opdenhövel?Produziert in HD</e2eventdescriptionextended>
		<e2eventservicereference>1:0:19:283D:3FB:1:C00000:0:0:0:</e2eventservicereference>
		<e2eventservicename>Das Erste HD</e2eventservicename>
	</e2event>
        ...

    RegEx:
      <e2eventid>(.*?)</e2eventid>
      .*?<e2eventstart>(.*?)</e2eventstart>
      .*?<e2eventduration>(.*?)</e2eventduration>
      .*?<e2eventcurrenttime>(.*?)</e2eventcurrenttime>
      .*?<e2eventtitle>(.*?)</e2eventtitle>
      .*?<e2eventdescription>(.*?)</e2eventdescription>
      .*?<e2eventdescriptionextended>(.*?)</e2eventdescriptionextended>
      .*?<e2eventservicereference>(.*?)</e2eventservicereference>
      .*?<e2eventservicename>(.*?)</e2eventservicename>
      .*?</e2event>

    Result:
      $1 [81 - 85]: 22435
      $2 [116 - 125]: 1402942500
      $3 [162 - 165]: 5700
      $4 [208 - 217]: 1402944714
      $5 [257 - 284]: FIFA WM 2014: Iran - Nigeria
      $6 [324 - 360]: Vorrunde Gruppe F (live, 1. Halbzeit)
      $7 [414 - 554]: * Übertragung aus Curitiba ab 21.00 Uhr?* Reporter: Steffen Simon?* Experte: Mehmet Scholl?* Moderation: Matthias Opdenhövel?Produziert in HD
      $8 [613 - 643]: 1:0:19:283D:3FB:1:C00000:0:0:0:
      $9 [694 - 705]: Das Erste HD
  *)

  RegEx.SetRegEx('<e2eventid>(.*?)</e2eventid>'+
                 '.*?<e2eventstart>(.*?)</e2eventstart>'+
                 '.*?<e2eventduration>(.*?)</e2eventduration>'+
                 '.*?<e2eventcurrenttime>(.*?)</e2eventcurrenttime>'+
                 '.*?<e2eventtitle>(.*?)</e2eventtitle>'+
                 '.*?<e2eventdescription>(.*?)</e2eventdescription>'+
                 '.*?<e2eventdescriptionextended>(.*?)</e2eventdescriptionextended>'+
                 '.*?<e2eventservicereference>(.*?)</e2eventservicereference>'+
                 '.*?<e2eventservicename>(.*?)</e2eventservicename>'+
                 '.*?</e2event>', true); // S = one line

  RegEx.Execute(PChar(sEPGData));

  while (true) and (RegEx.GetMatch(0)<>'') do begin

    ChannelProgram.sChannelId := ChannelID;

    try
      // extract program info
      ChannelProgram.sEventId   := RegEx.GetMatch(1);
      ChannelProgram.sDuration  := IntToStr(StrToInt(RegEx.GetMatch(3)) div 60);
      ChannelProgram.sStartSec  := RegEx.GetMatch(2);
      ChannelProgram.sStartTime := FormatDateTime('hh:mm', UnixToDateTime(StrToInt(ChannelProgram.sStartSec)));
      ChannelProgram.sTitle     := RegEx.GetMatch(5);
      ChannelProgram.sTitle     := ReplSubStr(ChannelProgram.sTitle, ''#$B'', ''); // don't know the reason anymore
      ChannelProgram.sInfo1     := RegEx.GetMatch(6);
      if ChannelProgram.sInfo1 = '' then
        ChannelProgram.sInfo1 := '-';

      APChar := StrAlloc(length(RegEx.GetMatch(7))+ 1);
      StrPCopy(APChar, RegEx.GetMatch(7));

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
