// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       Neutrino.dll - box interface dll for dboxTV
//   Version:       1.0
//
//   Function:      Http client, uses only dboxTV functions
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

unit UntHttpClient;

interface

uses
  SysUtils,

  UntDataDll;

{$LongStrings ON}

type
  // http client
  THttpClient = class(TObject)
  public
    FGetBoxData        : TDLL_GetBoxData; // get box data (ip/port/...)
    FLog               : TDLL_LogStr;     // log function
    FGetURL            : TDLL_GetURL;     // main http requests
    FGetURL_BIN        : TDLL_GetURL_BIN; // main http requests only for binary data
    FGetURL_EPG        : TDLL_GetURL_EPG; // epg http requests

    constructor Create(aGetBoxData, aLog, aGetURL, aGetURL_BIN, aGetURL_EPG : Pointer);reintroduce;

    function BuildURL(aURL,Tag,Tagdata : ShortString):String;
    function GetURL(aURL, Tag, Tagdata : ShortString): PChar; overload; virtual;
    function GetURL(aURL : ShortString): PChar; overload;
    function GetURL_BIN(aURL : ShortString): Pointer; overload;

    function GetURL_EPG(aURL, Tag, Tagdata : ShortString): PChar; overload; virtual;
    function GetURL_EPG(aURL : ShortString): PChar; overload;

    // string handling
    function ReplSubStr (TheString, OldSubStr, NewSubStr : ShortString) : ShortString;
  end;

implementation

{THttpClient}
(*******************************************************************************
 * INFO:
 *   constructor, init
 *
 * PARAMS:
 *   IP        : ip
 *   Port      : port
 *   User      : user
 *   Pass      : pass
 *   Log       : pointer to log function
 *   DoLogHttp : true = log http answers
 *
 * RGW:
 *   none
 ******************************************************************************)
constructor THttpClient.Create(aGetBoxData, aLog, aGetURL, aGetURL_BIN, aGetURL_EPG : Pointer);
begin
  TMethod(FGetBoxData).Code := aGetBoxData;
  TMethod(FLog).Code := aLog;
  TMethod(FGetURL).Code := aGetURL;
  TMethod(FGetURL_BIN).Code := aGetURL_BIN;
  TMethod(FGetURL_EPG).Code := aGetURL_EPG;
end;

(*******************************************************************************
 * INFO:
 *   build a url and replaces tag by tagdata
 *
 * PARAMS:
 *   URL : url without 'http://ip:port'
 *
 * RGW:
 *   real url
 ******************************************************************************)
function THttpClient.BuildURL(aURL, Tag, TagData : ShortString):String;
var
  MyURL : String;
begin

  MyURL := 'http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL;

  if Tag <> '' then
    MyURL := ReplSubStr(MyURL, Tag, TagData);

  Result := MyURL;
end;

(*******************************************************************************
 * INFO:
 *   replace a substring in a string
 *
 * PARAMS:
 *   TheString : string to trim
 *   OldSubStr : substring to be replaced by NewSubStr
 *   NewSubStr : new substring
 *
 * RGW:
 *   replaced string
 ******************************************************************************)
function THttpClient.ReplSubStr(TheString, OldSubStr, NewSubStr: ShortString): ShortString;
var
  P      : Integer;
  OldLen : Integer;
begin
  Result := '';
  OldLen := Length (OldSubStr);
  if OldLen = 0 then exit;
  repeat
    P := Pos (OldSubStr, TheString);
    if P = 0 then break;
    Result := Result + Copy (TheString, 1, P-1) + NewSubStr;

    TheString := Copy (TheString, P+OldLen, MaxInt);
  until false;
  Result := Result + TheString;
end;

function THttpClient.GetURL(aURL, Tag, Tagdata: ShortString): PChar;
var
  APChar : PChar;
begin
  APChar := StrAlloc(length(BuildURL(aURL,Tag,Tagdata)) + 1);
  StrPCopy(APChar, BuildURL(aURL,Tag,Tagdata));

  Result := FGetURL(APChar);

  StrDispose(APChar);
end;

function THttpClient.GetURL(aURL: ShortString): PChar;
var
  APChar : PChar;
begin
  APChar := StrAlloc(length('http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL) + 1);
  StrPCopy(APChar, 'http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL);

  Result := FGetURL(APChar);

  StrDispose(APChar);
end;

function THttpClient.GetURL_EPG(aURL, Tag, Tagdata: ShortString): PChar;
var
  APChar : PChar;
begin
  APChar := StrAlloc(length(BuildURL(aURL,Tag,Tagdata))+1);
  StrPCopy(APChar, BuildURL(aURL,Tag,Tagdata));

  Result := FGetURL_EPG(APChar);

  StrDispose(APChar);
end;

function THttpClient.GetURL_EPG(aURL: ShortString): PChar;
var
  APChar : PChar;
begin
  APChar := StrAlloc(length('http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL)+1);
  StrPCopy(APChar, 'http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL);

  Result := FGetURL_EPG(APChar);

  StrDispose(APChar);
end;

function THttpClient.GetURL_BIN(aURL: ShortString): Pointer;
var
  APChar : PChar;
begin
  APChar := StrAlloc(length('http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL)+1);
  StrPCopy(APChar, 'http://'+FGetBoxData().sIp+':'+FGetBoxData().sPort+aURL);

  Result := FGetURL_BIN(APChar);

  StrDispose(APChar);
end;

end.
