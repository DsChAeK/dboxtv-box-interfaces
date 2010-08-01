// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       Neutrino.dll - box interface dll for dboxTV
//   Version:       1.0
//
//   Function:      Data for exchange with dboxTV
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

unit UntDataDLL;

interface

const

  // #####################
  // #### constants ######
  // #####################

  // remote keys
  KEY_1          = 'KEY_1';
  KEY_2          = 'KEY_2';
  KEY_3          = 'KEY_3';
  KEY_4          = 'KEY_4';
  KEY_5          = 'KEY_5';
  KEY_6          = 'KEY_6';
  KEY_7          = 'KEY_7';
  KEY_8          = 'KEY_8';
  KEY_9          = 'KEY_9';
  KEY_0          = 'KEY_0';
  KEY_POWER      = 'KEY_POWER';
  KEY_HOME       = 'KEY_HOME';
  KEY_SETUP      = 'KEY_SETUP';
  KEY_RED        = 'KEY_RED';
  KEY_GREEN      = 'KEY_GREEN';
  KEY_YELLOW     = 'KEY_YELLOW';
  KEY_BLUE       = 'KEY_BLUE';
  KEY_UP         = 'KEY_UP';
  KEY_DOWN       = 'KEY_DOWN';
  KEY_LEFT       = 'KEY_LEFT';
  KEY_RIGHT      = 'KEY_RIGHT';
  KEY_OK         = 'KEY_OK';
  KEY_VOLUMEUP   = 'KEY_VOLUMEUP';
  KEY_VOLUMEDOWN = 'KEY_VOLUMEDOWN';
  KEY_MUTE       = 'KEY_MUTE';
  KEY_HELP       = 'KEY_HELP';

  // ###########################
  // #### data structures ######
  // ###########################

type

  // box data
  RBoxData = record
    sIp : ShortString;
    sPort : ShortString;
    sUser : ShortString;
    sPass : ShortString;        
  end;
        
  // stream info
  RStreamInfo = record
    sResolution  : ShortString; // resolution -> '720x576'
    sAspectRatio : ShortString; // video aspect ratio -> '4:3'
    sBitrate     : ShortString; // video bitrate -> '1875kbit'
    sFramerate   : ShortString; // video framerate -> '25 fps'
    sAudiotyp    : ShortString; // audiotyp -> 'stereo'
    sVPID        : ShortString; // video pid -> '0x0F0F'
    iAPIDCnt     : Integer;     // audio track count -> 2
    sAPID        : ShortString; // audio pids -> '0xEEFF,0xEEDD'
    sALANG       : ShortString; // audio language -> 'english,german'
    sPMT         : ShortString; // pmt -> '0x0E0E'
  end;

  // bouquet data
  RBouquet = record
    Name  : ShortString; // bouquet name -> 'bouquet1'
    Index : Integer;     // bouquet index -> 0
  end;

  // channel data
  RChannel = record
    Index        : Integer;     // index in a bouquet -> 9
    IndexGlobal  : Integer;     // global bouquet index -> 123
    sChannelId   : ShortString; // channel id -> '49100032ee9'
    sName        : ShortString; // channel name -> 'channel1'
    Mode         : ByteBool;    // mode -> true=tv, false=radio
    BouquetIndex : Integer;     // bouquet index -> 0
  end;
  
  // channel program data
  RChannelProgram = record
    sChannelId : ShortString; // channel id -> '45300014462'
    sEventId   : ShortString; // event id -> '306526254720614746'
    sDuration  : ShortString; // duration in minutes -> '130'
    sStartSec  : ShortString; // starttime as time_t string -> '1273947300'
    sStartTime : ShortString; // starttime as string -> '22:25'
    sTitle     : ShortString; // programm title (epg info) -> 'dog cat mouse'
    sInfo1     : ShortString; // programm info 1 (epg details) -> 'season 1'
    sInfo2     : PChar;       // programm info 2 (epg details) -> 'dog hunts cat, cat hunts mouse'
  end;

  // ###########################
  // #### function pointers ####
  // ###########################

  type
    // box data
    TDLL_GetBoxData = function ():RBoxData of object;
               
    // logging
    TDLL_LogStr = procedure (Text:PChar; Result : Integer) of object;

    // data
    TDLL_AddBouquet = function (Bouquet : RBouquet):Integer of object;
    TDLL_AddChannel = function (BouquetID:Integer; Channel : RChannel):Integer of object;
    TDLL_AddChannelProgram = function (BouquetIndex:Integer; ChannelIndex:Integer; ChannelProgram : RChannelProgram):Integer of object;

    // http client
    TDLL_GetURL = function (URL : PChar):PChar of object;
    TDLL_GetURL_BIN = function (URL : PChar):Pointer of object;
    TDLL_GetURL_EPG = function (URL : PChar):PChar of object;

    // regex engine
    TDLL_NewRegEx = function : Integer of object;
    TDLL_SetRegEx = procedure (iID : Integer; RegEx : PChar; ModifierS : ByteBool) of object;
    TDLL_GetMatch = function (iID : Integer; iNr : Integer) : PChar of object;
    TDLL_Execute = function (iID : Integer; Text : PChar) : Integer of object;
    TDLL_ExecuteNext = function (iID : Integer) : ByteBool of object;
    TDLL_SendTelnetCmd = function(sCmd : PChar; iWait : Integer):ByteBool of object;

implementation


end.
