//
//  esphost.h
//  DarkSword
//
//  ESP overlay host — DarkSword remake of the CrackTeam TrollStore HUD.
//
//  TrollStore version: a root "-hud" subprocess bootstraps its own
//  UIApplication plugin and registers its window with SpringBoard via
//  SBSAccessibilityWindowHostingController (entitlement-backed XPC).
//
//  DarkSword version: the app process itself hosts the ESP UIWindow and
//  performs the SAME registration, but the call runs INSIDE SpringBoard
//  through the RemoteCall session (SpringBoard is the AXSpringBoardServer
//  host, so no entitlement check applies to the caller). The window's
//  CAContext is composited by the render server on top of everything,
//  exactly like the TrollStore build; the floating menu is gone by design
//  (control lives in the ESP tab of the app).
//

#ifndef esphost_h
#define esphost_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Runtime status of the overlay pipeline (read by the Swift status UI).
typedef struct {
    bool     overlayWindow;      // ESP UIWindow created in this process
    bool     sbRegistered;       // registerWindowWithContextID: done in SpringBoard
    bool     tickLoop;           // frame tick timer running
    bool     keepAlive;          // background audio keep-alive active
    bool     gameRunning;        // FreeFire process alive (updated per frame)
    uint32_t registeredContextID;// context ID sent to SpringBoard (0 = none)
    uint32_t frameCount;         // ticks since start
    uint32_t lastEnemyCount;     // enemies drawn last frame (player+bot)
} ESPHostStatus;

// Full start: kernel bridge (esp_krw_init) -> overlay window -> SpringBoard
// registration -> tick loop -> audio keep-alive.
// MUST be called with an open SpringBoard RemoteCall session
// (see DarkswordMechanism session helpers) when `registerInSB` is true.
// Returns 0 on success, negative error code otherwise.
int esp_host_start(bool registerInSB);

// Stop everything and restore the kernel bridge port.
void esp_host_stop(void);

// One-shot SpringBoard registration for the current window. Requires an
// OPEN RemoteCall session. Returns 0 on success.
int esp_host_register_in_springboard(void);

// Live status snapshot (thread-safe).
void esp_host_get_status(ESPHostStatus *out);

// True while the overlay pipeline is running.
bool esp_host_active(void);

// Launches Free Fire from inside SpringBoard (SBSLaunchApplicationWithIdentifier
// via remote dlsym, SBApplicationController fallback). Requires an OPEN
// RemoteCall session. Returns 0 on success.
int esp_host_launch_game(void);

// Re-reads the ESPPrefs (NSUserDefaults) keys into the C-side drawing flags.
// Exposed here (instead of esp.h) because esp.h drags in C++ templates that
// the Swift bridging header cannot import.
void esphost_reload_esp_prefs(void);

// Auto-heal hook: gọi sau khi kernel bridge dựng lại cho một tiến trình
// game mới — xoá cache module base để ESP bắt lại UnityFramework.
void esphost_on_game_relaunched(void);

// Audio keep-alive (silent loop + UIBackgroundModes=audio) — giữ process
// không bị suspend khi app vào nền. ESPEngine bật NGAY sau Start Darksword
// (trước khi user rời app sang game), không chờ tới esp_host_start.
// Idempotent: gọi nhiều lần không sao. esp_host_stop() tự gọi stop.
void esphost_start_keepalive(void);
void esphost_stop_keepalive(void);

#ifdef __cplusplus
}
#endif

#endif /* esphost_h */
