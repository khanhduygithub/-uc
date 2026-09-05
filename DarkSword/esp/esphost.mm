//
//  esphost.m
//  DarkSword
//
//  DarkSword remake of the CrackTeam TrollStore HUD overlay. See esphost.h.
//
//  SpringBoard registration (the only entitlement-gated call in the
//  TrollStore build) is re-created here with a remote NSInvocation chain:
//
//    [NSMethodSignature signatureWithObjCTypes:"v@:Id"]   (in SpringBoard)
//    [NSInvocation invocationWithMethodSignature:]        (in SpringBoard)
//    [invocation setTarget: SBSAccessibilityWindowHostingController new]
//    [invocation setSelector: @selector(registerWindowWithContextID:atLevel:)]
//    [invocation setArgument:&ctxID atIndex:2]   (uint32, remote scratch buf)
//    [invocation setArgument:&level atIndex:3]   (double — why NSInvocation:
//      the RemoteCall thread-state machinery only restores integer registers
//      x0-x28, so a double argument cannot be passed through objc_msgSend
//      directly; NSInvocation packs d0 internally and the whole chain runs
//      on plain integer-register calls)
//    [invocation invoke]                          (on SpringBoard main)
//
//  Background survival: the app plays a silent looping audio track with
//  UIBackgroundModes=audio so SpringBoard never suspends the process while
//  the user is in the game (the TrollStore HUD process was spawned detached
//  and never suspended — this is the DarkSword-native equivalent).
//

#import "esphost.h"
#import "espkrw.h"
#import "drawing_view/esp.h"

#import "../TaskRop/RemoteCall.h"
#import "../tweaks/remote_objc.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <mach/mach.h>
#import <stdatomic.h>

#pragma mark - Window (hit-test transparent inside our own app)

@interface UIWindow (ESPPrivate)
- (unsigned int)_contextId;
@end

@interface ESPHostWindow : UIWindow
@end

@implementation ESPHostWindow
// The overlay must never eat touches in OUR app; the hosted context on the
// SpringBoard side is display-only for the game (same as the CrackTeam ESP
// view which ran with userInteractionEnabled = NO).
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
@end

#pragma mark - State

static ESPHostWindow   *g_window   = nil;
static ESP_View        *g_view     = nil;
static dispatch_source_t g_tick    = NULL;
static AVAudioPlayer   *g_silence  = nil;

static atomic_bool g_overlayWindow  = false;
static atomic_bool g_sbRegistered   = false;
static atomic_bool g_tickLoop       = false;
static atomic_bool g_keepAlive      = false;
static atomic_bool g_gameRunning    = false;
static atomic_uint g_contextID      = 0;
static atomic_uint g_frameCount     = 0;
static atomic_uint g_lastEnemyCount = 0;

#define ESPHOST_LOG(fmt, ...) printf("[ESPHOST] " fmt "\n", ##__VA_ARGS__)

#pragma mark - C hook from ESP_View (esp.mm)

void esp_set_game_running(bool running) {
    atomic_store(&g_gameRunning, running);
}

void esp_set_enemy_count(int count) {
    atomic_store(&g_lastEnemyCount, count > 0 ? (uint32_t)count : 0);
}

void esphost_reload_esp_prefs(void) {
    ESPSyncFromPrefs();
}

void esphost_on_game_relaunched(void) {
    extern uint64_t Moudule_Base;      // esp.mm
    Moudule_Base = (uint64_t)-1;       // buộc updateFrame tìm lại module base
    esp_memory_reset_cache();          // pid.mm: cachedBase + get_task
    ESPHOST_LOG("game mới — đã reset cache module base");
}

#pragma mark - SpringBoard registration

int esp_host_register_in_springboard(void) {
    if (!g_window) {
        ESPHOST_LOG("chưa có window — bỏ qua đăng ký");
        return -1;
    }

    uint32_t contextID = (uint32_t)[g_window _contextId];
    if (!contextID) {
        ESPHOST_LOG("không lấy được _contextId của window");
        return -2;
    }
    double level = 10000010.0; // same level the TrollStore HUD used
    atomic_store(&g_contextID, contextID);
    ESPHOST_LOG("context ID=%u level=%.1f — đăng ký qua RemoteCall trong SpringBoard…", contextID, level);

    // Scratch buffer in SpringBoard for NSInvocation setArgument copies.
    uint64_t scratch = remote_call_trojan_mem();
    if (!scratch) {
        ESPHOST_LOG("không có trojan memory (session chưa mở?)");
        return -3;
    }

    // +[NSMethodSignature signatureWithObjCTypes:"v@:Id"]
    uint64_t strTypes = r_alloc_str("v@:Id");
    if (!strTypes) { ESPHOST_LOG("r_alloc_str thất bại"); return -4; }
    uint64_t clsMSig = r_class("NSMethodSignature");
    uint64_t sig = r_msg(clsMSig, r_sel("signatureWithObjCTypes:"), strTypes, 0, 0, 0);
    if (!r_is_objc_ptr(sig)) { ESPHOST_LOG("signatureWithObjCTypes: thất bại"); return -5; }

    // [NSInvocation invocationWithMethodSignature:]
    uint64_t clsInv = r_class("NSInvocation");
    uint64_t inv = r_msg(clsInv, r_sel("invocationWithMethodSignature:"), sig, 0, 0, 0);
    if (!r_is_objc_ptr(inv)) { ESPHOST_LOG("invocationWithMethodSignature: thất bại"); return -6; }

    // target = [[SBSAccessibilityWindowHostingController alloc] init]
    uint64_t clsSBS = r_class("SBSAccessibilityWindowHostingController");
    if (!clsSBS) { ESPHOST_LOG("SpringBoard không có class SBSAccessibilityWindowHostingController"); return -7; }
    uint64_t inst = r_msg(clsSBS, r_sel("alloc"), 0, 0, 0, 0);
    inst = r_msg(inst, r_sel("init"), 0, 0, 0, 0);
    if (!r_is_objc_ptr(inst)) { ESPHOST_LOG("không tạo được SBSAccessibilityWindowHostingController trong SpringBoard"); return -8; }

    if (!r_responds(inst, "registerWindowWithContextID:atLevel:")) {
        ESPHOST_LOG("SpringBoard không phản hồi registerWindowWithContextID:atLevel:");
        return -9;
    }

    r_msg(inv, r_sel("setTarget:"), inst, 0, 0, 0);
    r_msg(inv, r_sel("setSelector:"), r_sel("registerWindowWithContextID:atLevel:"), 0, 0, 0);

    // Arguments: (uint32)contextID @2, (double)level @3.
    // setArgument:atIndex: copies FROM a remote buffer -> write the values
    // into SpringBoard memory first (trojan page is RW).
    if (!remote_write(scratch + 0, &contextID, 4)) { ESPHOST_LOG("remote_write contextID thất bại"); return -10; }
    if (!remote_write(scratch + 16, &level, 8)) { ESPHOST_LOG("remote_write level thất bại"); return -11; }
    r_msg(inv, r_sel("setArgument:atIndex:"), scratch, 2, 0, 0);
    r_msg(inv, r_sel("setArgument:atIndex:"), scratch + 16, 3, 0, 0);

    // Run on SpringBoard's main thread (window server state).
    r_msg_main(inv, r_sel("invoke"), 0, 0, 0, 0);

    atomic_store(&g_sbRegistered, true);
    ESPHOST_LOG("đăng ký SpringBoard HOÀN TẤT (context %u @ level %.0f)", contextID, level);
    return 0;
}

#pragma mark - Audio keep-alive

static void esphost_start_keepalive(void) {
    if (g_silence) return;
    @try {
        NSError *err = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&err];
        [session setActive:YES error:&err];

        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"silence" ofType:@"wav"]];
        if (!url) {
            ESPHOST_LOG("thiếu silence.wav — keep-alive tắt (ESP sẽ đóng băng khi app vào nền)");
            return;
        }
        g_silence = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
        if (!g_silence) {
            ESPHOST_LOG("không tạo được AVAudioPlayer: %s", err.localizedDescription.UTF8String ?: "không rõ");
            return;
        }
        g_silence.numberOfLoops = -1;   // loop forever
        g_silence.volume = 0.0f;
        [g_silence play];
        atomic_store(&g_keepAlive, true);
        ESPHOST_LOG("audio keep-alive đang chạy — app không bị suspend khi vào nền");
    } @catch (NSException *ex) {
        ESPHOST_LOG("keep-alive exception: %s — %s", ex.name.UTF8String ?: "NSException", ex.reason.UTF8String ?: "");
    }
}

static void esphost_stop_keepalive(void) {
    if (g_silence) {
        [g_silence stop];
        g_silence = nil;
    }
    atomic_store(&g_keepAlive, false);
    @try {
        [[AVAudioSession sharedInstance] setActive:NO
                                        withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                              error:nil];
    } @catch (NSException *ex) {
        (void)ex;
    }
}

#pragma mark - Tick loop

static void esphost_start_tick(void) {
    if (g_tick) return;
    g_tick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(g_tick,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              16.7 * NSEC_PER_MSEC,   // ~60Hz
                              5 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(g_tick, ^{
        if (g_view) {
            [g_view tickFrame];
            atomic_fetch_add(&g_frameCount, 1);
        }
    });
    dispatch_resume(g_tick);
    atomic_store(&g_tickLoop, true);
    ESPHOST_LOG("tick loop 60Hz đã khởi động (main queue)");
}

static void esphost_stop_tick(void) {
    if (g_tick) {
        dispatch_source_cancel(g_tick);
        g_tick = NULL;
    }
    atomic_store(&g_tickLoop, false);
}

#pragma mark - Public API

int esp_host_start(bool registerInSB) {
    if (g_window) {
        ESPHOST_LOG("overlay đang chạy");
        return 0;
    }

    // 1. kernel bridge
    int kr = esp_krw_init();
    if (kr != 0) {
        ESPHOST_LOG("esp_krw_init thất bại (%d)", kr);
        return kr;
    }

    // 2. overlay window (fullscreen, same level as the TrollStore HUD)
    // UIKit phải chạy trên main thread — esp_host_start có thể được gọi từ
    // queue nền (ESPEngine), nên đồng bộ sang main để tạo window/view.
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIScreen *screen = [UIScreen mainScreen];
        CGRect bounds = screen.bounds;
        BOOL landscape = bounds.size.width < bounds.size.height; // game runs landscape
        if (landscape) {
            CGFloat w = MAX(bounds.size.width, bounds.size.height);
            CGFloat h = MIN(bounds.size.width, bounds.size.height);
            bounds = CGRectMake(0, 0, w, h);
        }

        g_window = [[ESPHostWindow alloc] initWithFrame:bounds];
        g_window.windowLevel = 10000010.0;
        g_window.backgroundColor = [UIColor clearColor];
        g_window.hidden = NO;
        g_window.userInteractionEnabled = NO;

        g_view = [[ESP_View alloc] initWithFrame:bounds];
        g_view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        g_view.backgroundColor = [UIColor clearColor];
        [g_window addSubview:g_view];
        [g_window makeKeyAndVisible];
        atomic_store(&g_overlayWindow, true);
        ESPHOST_LOG("ESP window %gx%g @ level %.0f đã tạo (hit-test transparent)",
                    bounds.size.width, bounds.size.height, (double)g_window.windowLevel);
    });

    // 3. SpringBoard registration (caller must hold an open session)
    if (registerInSB) {
        int reg = esp_host_register_in_springboard();
        if (reg != 0) {
            ESPHOST_LOG("đăng ký SpringBoard thất bại (%d) — window vẫn tạo, có thể thử đăng ký lại", reg);
        }
    }

    // 4. tick loop + keep-alive
    esphost_start_tick();
    esphost_start_keepalive();

    ESPHOST_LOG("===== ESP overlay HOÀN TẤT =====");
    return 0;
}

void esp_host_stop(void) {
    esphost_stop_tick();
    esphost_stop_keepalive();
    if (g_window) {
        [g_window setHidden:YES];
        g_view = nil;
        g_window = nil;
    }
    atomic_store(&g_overlayWindow, false);
    atomic_store(&g_sbRegistered, false);
    atomic_store(&g_contextID, 0);
    atomic_store(&g_frameCount, 0);
    atomic_store(&g_lastEnemyCount, 0);
    atomic_store(&g_gameRunning, false);
    esp_krw_stop();
    ESPHOST_LOG("ESP overlay đã dừng");
}

void esp_host_get_status(ESPHostStatus *out) {
    if (!out) return;
    out->overlayWindow      = atomic_load(&g_overlayWindow);
    out->sbRegistered       = atomic_load(&g_sbRegistered);
    out->tickLoop           = atomic_load(&g_tickLoop);
    out->keepAlive          = atomic_load(&g_keepAlive);
    out->gameRunning        = atomic_load(&g_gameRunning);
    out->registeredContextID= atomic_load(&g_contextID);
    out->frameCount         = atomic_load(&g_frameCount);
    out->lastEnemyCount     = atomic_load(&g_lastEnemyCount);
}

bool esp_host_active(void) {
    return atomic_load(&g_overlayWindow);
}

int esp_host_launch_game(void) {
    // Path 1: SBSLaunchApplicationWithIdentifier (SpringBoardServices, loaded
    // inside SpringBoard) — same call the TrollStore entitlement allowed.
    uint64_t bundle = r_cfstr("vn.vng.freefireth");
    if (!bundle) {
        ESPHOST_LOG("r_cfstr thất bại");
        return -1;
    }
    uint64_t ret = r_dlsym_call(5, "SBSLaunchApplicationWithIdentifier", bundle, 0, 0, 0, 0, 0, 0, 0);
    if (ret != 0) {
        ESPHOST_LOG("SBSLaunchApplicationWithIdentifier -> %llu", ret);
        return 0;
    }
    // Path 2: [[SBApplicationController sharedInstance] launchApplicationWithBundleID:]
    uint64_t cls = r_class("SBApplicationController");
    uint64_t ctrl = r_msg(cls, r_sel("sharedInstance"), 0, 0, 0, 0);
    if (r_is_objc_ptr(ctrl) &&
        r_responds(ctrl, "launchApplicationWithBundleID:")) {
        r_msg_main(ctrl, r_sel("launchApplicationWithBundleID:"), bundle, 0, 0, 0);
        ESPHOST_LOG("SBApplicationController launchApplicationWithBundleID: đã gửi");
        return 0;
    }
    ESPHOST_LOG("không tìm được đường dẫn mở game trong SpringBoard");
    return -2;
}
