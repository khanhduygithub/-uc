//
//  rssidisplay.h
//  DarkSword
//
//  Ported from Cyanide / darksword-kexploit-fun — covers the SpringBoard
//  status-bar signal icons with live dBm readouts.
//
//  All three calls operate on an already-open SpringBoard RemoteCall session
//  (init_remote_call("SpringBoard", ...) must have succeeded first).
//

#ifndef rssidisplay_h
#define rssidisplay_h

#import <stdint.h>
#import <stdbool.h>

// Replace the status-bar wifi/cellular signal bars with live dBm labels.
// Pass false for either side to skip it. Safe to re-apply periodically
// (refreshes label text in place).
bool rssidisplay_apply_in_session(bool showWifi, bool showCell);

// Remove the dBm labels and restore the stock signal bar layers.
bool rssidisplay_stop_in_session(void);

// Drop every cached remote pointer (call after a SpringBoard respring —
// the old label/view addresses are stale after the process restarts).
void rssidisplay_forget_remote_state(void);

#endif /* rssidisplay_h */
