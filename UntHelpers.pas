// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       Neutrino.dll - box interface dll for dboxTV
//   Version:       1.0
//
//   Function:      String handling
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

unit UntHelpers;

interface

uses  SysUtils;

procedure SplitString (TheText, Delim : String; var Key, Value : String);
function  ReplSubStr (TheString, OldSubStr, NewSubStr : String) : String;

implementation

(*******************************************************************************
 * INFO:
 *   split a string into two parts
 *
 * PARAMS:
 *   TheText : string to be split
 *   Delim   : split on this substring
 *   Key     : left part of splitted string
 *   Value   : right part of splitted string
 *
 * RGW:
 *   none
 ******************************************************************************)
procedure SplitString (TheText, Delim : String; var Key, Value : String);
var
  P : Integer;
begin
  P := Pos (Delim, TheText);
  if P <> 0 then begin
    Key   := Trim (Copy (TheText, 1, P-1));

    Value := Trim (Copy (TheText, P+Length(Delim), MaxInt));
    end
  else begin
    Key   := Trim (TheText);
    Value := '';
    end;
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
 *   trimmed string
 ******************************************************************************)
function ReplSubStr (TheString, OldSubStr, NewSubStr : String) : String;
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

end.
