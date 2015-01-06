// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       Neutrino.dll - box interface dll for dboxTV
//   Version:       1.0
//
//   Function:      RegEx Handling, uses only dboxTV functions
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
// Info: TRegEx shows you how to handle the dboxTV regex functions, which are
//       called by function pointers.
//       
// Usage:
//            // text to parse
//            '<channel service_id="7031" name="EinsExtra" service_type="0001" />
//             <channel service_id="7032" name="Einsfestival" service_type="0001" />
//             <channel service_id="7033" name="EinsPlus" service_type="0001" />'
//
//            // set your regular expression
//            SetRegEx('<channel service_id="(.*?)" '+
//                     'name="(.*?)" '+
//                     'service_type="(.*?)".*?>',
//                     false);
//
//            // execute, the matches for your regex will be stored in a list
//            Execute(sTemp);
//
//            // catch the matches from the stored list
//            GetMatch(0): '<channel service_id="7031" name="EinsExtra" service_type="0001" />'
//            GetMatch(1): '7031'
//            GetMatch(2): 'EinsExtra'
//            GetMatch(3): '0001'
//
//            // get next result, the matches list will be overwritten!
//            ExecuteNext;
//
//            // catch the matches from the stored list again
//            GetMatch(0): '<channel service_id="7032" name="Einsfestival" service_type="0001" />'
//            GetMatch(1): '7032'
//            ...
//
//            Hints:
//            - all things between '()' in a expression will be a Match in the List.
//            - GetMatch(0) is always the whole line which was found and parsed
//
//
// ##############################################################################################

unit UntRegEx;

interface

uses
  SysUtils, Classes,

  UntDataDLL;

{$LongStrings ON}

type
  // regex
  TRegEx = class(TObject)
  private
    FID : Integer;

    FNewRegEx    : TDLL_NewRegEx;     // create new regex object
    FSetRegEx    : TDLL_SetRegEx;     // set the expression
    FGetMatch    : TDLL_GetMatch;     // get match by index
    FExecute     : TDLL_Execute;      // execute regex
    FExecuteNext : TDLL_ExecuteNext;  // execute next regex
    FFreePChar   : TDLL_FreePChar;    // free pchar mem from dboxTV

    FMatches     : TStringList;       // storage for all matches of one FExecute or FExecuteNext
  public
    function  NewRegEx() : Integer;
    procedure SetRegEx(RegEx : pChar; ModifierS : ByteBool);
    function  GetMatch(iNr : Integer) : String;
    function  Execute(Text : PChar) : Integer; // -> counter
    function  ExecuteNext() : ByteBool;

    constructor Create(FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext, FktFreePChar : Pointer); reintroduce;
  end;

implementation

{TRegEx}
(*******************************************************************************
 * INFO:
 *   constructor, init
 *
 * PARAMS:
 *   FktNewRegEx    : create a new regex object in dboxTV
 *   FktSetRegEx    : set your expression
 *   FktGetMatch    : get a match from match array by index
 *   FktExecute     : execute regex
 *   FktExecuteNext : execute next regex
 *
 * RGW:
 *   none
 ******************************************************************************)
constructor TRegEx.Create(FktNewRegEx, FktSetRegEx, FktGetMatch, FktExecute, FktExecuteNext, FktFreePChar : Pointer);
begin
  FMatches := TStringList.Create();

  TMethod(FNewRegEx).Code := FktNewRegEx;
  TMethod(FSetRegEx).Code := FktSetRegEx;
  TMethod(FGetMatch).Code := FktGetMatch;
  TMethod(FExecute).Code := FktExecute;
  TMethod(FExecuteNext).Code := FktExecuteNext;
  TMethod(FFreePChar).Code := FktFreePChar;

  FID := FNewRegEx();
end;

(*******************************************************************************
 * INFO:
 *   execute regex, searches first string
 *
 * PARAMS:
 *   Text : text to parse
 *
 * RGW:
 *   match count
 ******************************************************************************)
function TRegEx.Execute(Text: PChar) : Integer;
var
  i : Integer;
  sMatch : PChar;
  sTemp : String;
begin
  if Text = '' then begin
    Result := -1;
    exit;
  end;

  Result := FExecute(FID, Text);

  // clear all matches
  FMatches.Clear;

  // store all matches
  for i := 0 to Result-1 do begin
    sTemp := '';
    sMatch := FGetMatch(FID, i);

    if sMatch <> nil then begin
      sTemp := sMatch;
      FFreePChar(sMatch);
    end;

    FMatches.Add(sTemp);
  end;
end;

(*******************************************************************************
 * INFO:
 *   execute next regex, searches for next string
 *
 * RGW:
 *   true = found next string
 *   false = nothing found anymore
 ******************************************************************************)
function TRegEx.ExecuteNext : ByteBool;
var
  i, iCnt : Integer;
  sMatch : PChar;
  sTemp : String;
begin
try
  // execute next
  Result := FExecuteNext(FID);
except
  Result := false;
  exit;
end;

  // clear all matches
  iCnt := FMatches.Count; // is always the first time amount
  FMatches.Clear;

  // store all matches
  for i := 0 to iCnt-1 do begin
    sTemp := '';
    sMatch := FGetMatch(FID, i);

    if sMatch <> nil then begin
      sTemp := sMatch;
      FFreePChar(sMatch);
    end;
    
    FMatches.Add(sTemp);
  end;
end;

(*******************************************************************************
 * INFO:
 *   extract a match from list of matches
 *
 * PARAMS:
 *   iNr : list index
 *
 * RGW:
 *   match as char array
 ******************************************************************************)
function TRegEx.GetMatch(iNr: Integer): String;
begin
  Result := '';

  if iNr >= FMatches.Count then
    exit;

  Result := FMatches.Strings[iNr];
end;

(*******************************************************************************
 * INFO:
 *   creates a new regex object in dboxTV
 *
 * RGW:
 *   distinct id, used by other functions for working with this object
 ******************************************************************************)
function TRegEx.NewRegEx: Integer;
begin
  Result := FNewRegEx();
end;

(*******************************************************************************
 * INFO:
 *   set the expression
 *
 * PARAMS:
 *   RegEx     : expression
 *   ModifierS : true=treat text as one line, false=treat text as single line
 *
 * RGW:
 *   match as char array
 ******************************************************************************)
procedure TRegEx.SetRegEx(RegEx: pChar; ModifierS : ByteBool);
begin
  FSetRegEx(FID, RegEx, ModifierS);
end;

end.
