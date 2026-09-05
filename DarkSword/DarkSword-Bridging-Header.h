// DarkSword bridging header
// — kernel exploit (upgraded to the Cyanide superset: kexploit_krw_ready,
//   persistence, vnode APFS helpers)
// — Darksword mechanism ported from Cyanide (TaskRop RemoteCall + tweaks)

#import "kexploit/kexploit_opa334.h"
#import "kexploit/sandbox_escape.h"
#import "kexploit/kutils.h"
#import "kexploit/persistence.h"

// Remote-call infrastructure (TaskRop) — opens a RemoteCall session into
// SpringBoard so the darksword tweaks can run in the SpringBoard process.
#import "TaskRop/RemoteCall.h"

// Darksword mechanism (ported verbatim from Cyanide 1.3.6)
#import "tweaks/darksword_tweaks.h"
#import "tweaks/darksword_drag.h"
#import "tweaks/darksword_layout.h"
#import "tweaks/darksword_ota.h"
#import "tweaks/rssidisplay.h"

// ESP Free Fire (remake of the CrackTeam TrollStore external HUD on the
// darksword kernel R/W bridge)
#import "esp/espkrw.h"
#import "esp/esphost.h"
#import "esp/drawing_view/ESPPrefs.h"
