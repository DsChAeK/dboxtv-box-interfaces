// ##############################################################################################
//   Author:        DsChAeK
//   URL:           http://www.dschaek.de
//   Project:       Neutrino - Box Interface DLL für Anbindung an dboxTV
//   Version:       1.0
//
//   Function:      Box specific URLs
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
// Info:  TAG_INFO can be used to replace tag with data
//
// ##############################################################################################

unit UntURL;

interface
 
const

  // tag, a template to be replaced
  TAG_DATA                    = '<data>';

  // urls without 'http://ip:port'
  URL_DBOX_SETTINGS           = '/control/info?settings';
  URL_DBOX_STREAMINFO         = '/control/info?streaminfo';
  URL_DBOX_GETALLPIDS         = '/control/zapto?getallpids';
  URL_DBOX_BOUQUETLIST        = '/control/getbouquets';
  URL_DBOX_GETSERVICESXML     = '/control/getservicesxml';
  URL_DBOX_GETBOUQUETSXML     = '/control/getbouquetsxml';
  URL_DBOX_MESSAGE            = '/control/message?nmsg='+TAG_DATA;
  URL_DBOX_CHANNEL_SUBCHANS   = '/control/zapto?getallsubchannels';
  URL_DBOX_ZAPTO              = '/control/zapto';
  URL_DBOX_ZAPTO_CHAN         = '/control/zapto?'+TAG_DATA;
  URL_DBOX_EPGEXT             = '/control/epg?ext';
  URL_DBOX_EPGPROGRAMS        = '/control/epg?xml=true&channelid='+TAG_DATA+'&details=true';
  URL_DBOX_SHUTDOWN           = '/control/shutdown';
  URL_DBOX_STANDBY            = '/control/standby?on';
  URL_DBOX_WAKEUP             = '/control/standby?off';
  URL_DBOX_RECORDSTATUS       = '/control/setmode?status';
  URL_DBOX_REBOOT             = '/control/reboot';
  URL_DBOX_SPTS               = '/control/system?getAViAExtPlayBack';
  URL_DBOX_SPTS_ON            = '/control/system?setAViAExtPlayBack=spts';
  URL_DBOX_SPTS_OFF           = '/control/system?setAViAExtPlayBack=pes';
  URL_DBOX_TIME               = '/control/gettime?rawtime';
  URL_DBOX_UDP_START          = '/control/exec?api udp_stream start';
  URL_DBOX_UDP_STOP           = '/control/exec?api udp_stream stop';
  URL_DBOX_RC_LOCK            = '/control/rc?lock';
  URL_DBOX_RC_UNLOCK          = '/control/rc?unlock';
  URL_DBOX_GETMODE            = '/control/getmode';
  URL_DBOX_SETMODE            = '/control/setmode?'+TAG_DATA;
  URL_DBOX_OSDSHOT            = '/tmp/a.bmp';
  URL_DBOX_OSDSHOT_EXEC       = '/bin/dboxshot -o /tmp/a.bmp';
  URL_DBOX_RCEM               = '/control/rcem?'+TAG_DATA;

implementation

end.
