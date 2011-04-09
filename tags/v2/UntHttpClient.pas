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
    sHttpAnswer        : String;          // http answer as string
    sHttpAnswer_EPG    : String;          // http answer as string (epg data)
    HttpAnswer_BIN     : Pointer;         // http answer as pointer (binary data)

    FGetBoxData        : TDLL_GetBoxData; // get box data (ip/port/...)
    FLog               : TDLL_LogStr;     // log function
    FGetURL            : TDLL_GetURL;     // main http requests
    FGetURL_BIN        : TDLL_GetURL_BIN; // main http requests only for binary data
    FGetURL_EPG        : TDLL_GetURL_EPG; // epg http requests
    FFreePChar         : TDLL_FreePChar;  // free pchar mem allocated by dboxTV

    constructor Create(aGetBoxData, aLog, aGetURL, aGetURL_BIN, aGetURL_EPG, aFFreePChar : Pointer);reintroduce;

    function BuildURL(BoxID : Integer; aURL,Tag,Tagdata : ShortString):String;
    function GetURL(BoxID : Integer; aURL, Tag, Tagdata : ShortString): PChar; overload; virtual;
    function GetURL(BoxID : Integer; aURL : ShortString): PChar; overload;
    function GetURL_BIN(BoxID : Integer; aURL : ShortString): Pointer; overload;

    function GetURL_EPG(BoxID : Integer; aURL, Tag, Tagdata : ShortString): PChar; overload; virtual;
    function GetURL_EPG(BoxID : Integer; aURL : ShortString): PChar; overload;

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
 *   aGetBoxData  : pointer to boxdata function
 *   aLog         : pointer to log function
 *   aGetURL      : pointer to http function for normal urls
 *   aGetURL_BIN  : pointer to http function for binary data
 *   aGetURL_EPG  : pointer to http function for epg
 *   aFFreePChar  : pointer to dboxtv function to free pchar mem
 *
 * RGW:
 *   none
 ******************************************************************************)
constructor THttpClient.Create(aGetBoxData, aLog, aGetURL, aGetURL_BIN, aGetURL_EPG, aFFreePChar : Pointer);
begin
  TMethod(FGetBoxData).Code := aGetBoxData;
  TMethod(FLog).Code := aLog;
  TMethod(FGetURL).Code := aGetURL;
  TMethod(FGetURL_BIN).Code := aGetURL_BIN;
  TMethod(FGetURL_EPG).Code := aGetURL_EPG;
  TMethod(FFreePChar).Code := aFFreePChar;
end;

(*******************************************************************************
 * INFO:
 *   build a url and replaces tag by tagdata
 *
 * PARAMS:
 *   aURL : url without 'http://ip:port'
 *   Tag  : replaced by data
 *   Data : inserted data
 *
 * RGW:
 *   real url
 ******************************************************************************)
function THttpClient.BuildURL(BoxID : Integer; aURL, Tag, TagData : ShortString):String;
var
  MyURL : String;
begin

  MyURL := 'http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL;

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

(*******************************************************************************
 * INFO:
 *   get data from url
 *
 * PARAMS:
 *   aURL    : url without 'http://ip:port'
 *   Tag     : tag
 *   Tagdata : tag data
 *
 * RGW:
 *   data (ascii)
 ******************************************************************************)
function THttpClient.GetURL(BoxID : Integer; aURL, Tag, Tagdata: ShortString): PChar;
var
  APChar : PChar;
begin
  // alloc url
  APChar := StrAlloc(length(BuildURL(BoxID, aURL,Tag,Tagdata)) + 1);
  StrPCopy(APChar, BuildURL(BoxID, aURL,Tag,Tagdata));

  // call dboxTV function
  Result := FGetURL(BoxID, APChar);

  // copy answer to own string
  sHttpAnswer := Result;

  // free answer from dboxTV
  FFreePChar(Result);

  // free url
  StrDispose(APChar);

  Result := PChar(sHttpAnswer);
end;

(*******************************************************************************
 * INFO:
 *   get data from url
 *
 * PARAMS:
 *   aURL : url without 'http://ip:port'
 *
 * RGW:
 *   data (ascii)
 ******************************************************************************)
function THttpClient.GetURL(BoxID : Integer; aURL: ShortString): PChar;
var
  APChar : PChar;
begin
  // alloc url
  APChar := StrAlloc(length('http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL) + 1);
  StrPCopy(APChar, 'http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL);

  // call dboxTV function
  Result := FGetURL(BoxID, APChar);

  // copy answer to own string
  sHttpAnswer := Result;

  // free answer from dboxTV
  FFreePChar(Result);

  // free url
  StrDispose(APChar);

  Result := PChar(sHttpAnswer);
end;

(*******************************************************************************
 * INFO:
 *   get epg data from url, USE ONLY FOR EPG DATA!
 *
 * PARAMS:
 *   aURL    : url without 'http://ip:port'
 *   Tag     : tag
 *   Tagdata : tag data
 *
 * RGW:
 *   epg data (ascii)
 ******************************************************************************)
function THttpClient.GetURL_EPG(BoxID : Integer; aURL, Tag, Tagdata: ShortString): PChar;
var
  APChar : PChar;
begin
  // alloc url
  APChar := StrAlloc(length(BuildURL(BoxID, aURL,Tag,Tagdata)) + 1);
  StrPCopy(APChar, BuildURL(BoxID, aURL,Tag,Tagdata));

  // call dboxTV function
  Result := FGetURL_EPG(BoxID, APChar);

  // copy answer to own string
  sHttpAnswer_EPG := Result;

  // free answer from dboxTV
  FFreePChar(Result);

  // free url
  StrDispose(APChar);

  Result := PChar(sHttpAnswer_EPG);
end;

(*******************************************************************************
 * INFO:
 *   get epg data from url, USE ONLY FOR EPG DATA!
 *
 * PARAMS:
 *   aURL : url without 'http://ip:port'
 *
 * RGW:
 *   epg data (ascii)
 ******************************************************************************)
function THttpClient.GetURL_EPG(BoxID : Integer; aURL: ShortString): PChar;
var
  APChar : PChar;
begin
  // alloc url
  APChar := StrAlloc(length('http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL) + 1);
  StrPCopy(APChar, 'http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL);

  // call dboxTV function
  Result := FGetURL_EPG(BoxID, APChar);

  // copy answer to own string
  sHttpAnswer_EPG := Result;

  // free answer from dboxTV
  FFreePChar(Result);

  // free url
  StrDispose(APChar);

  Result := PChar(sHttpAnswer_EPG);  
end;

(*******************************************************************************
 * INFO:
 *   get binary data from url
 *
 * PARAMS:
 *   aURL : url without 'http://ip:port'
 *
 * RGW:
 *   binary data from http answer
 ******************************************************************************)
function THttpClient.GetURL_BIN(BoxID : Integer; aURL: ShortString): Pointer;
var
  APChar : PChar;
begin
  // alloc url
  APChar := StrAlloc(length('http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL) + 1);
  StrPCopy(APChar, 'http://'+FGetBoxData(BoxID).sIp+':'+FGetBoxData(BoxID).sPort+aURL);

  // call dboxTV function
  Result := FGetURL_BIN(BoxID, APChar);

  // copy answer to own string
  HttpAnswer_BIN := Result;

  // free answer from dboxTV
//  FFreePChar(Result);

  // free url
  StrDispose(APChar);

  Result := HttpAnswer_BIN;
end;

end.
