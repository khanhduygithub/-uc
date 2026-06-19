#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#include <iostream>
#include <UIKit/UIKit.h>
#include <vector>
#import "pthread.h"
#include <array>
#import "menuUIKIT/drawview.h"
#import "menuUIKIT/touchView.h"
#import "Themes/ThemeManager.h"
#import "Themes/UIComponents.h"
#import "menuUIKIT/Vars.h"
// API removed - no license check
#import <unistd.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <stdlib.h>
#import <os/log.h>
#include <cmath>
#include <deque>
#include <fstream>
#include <algorithm>
#import "Esp/SecureMap.h"
#import "JRMemory.framework/JRHelper.h"
// APIClient removed - no license system
#include <string>
#include "JRMemory.framework/Headers/MemScan.h"
#include <map>
#include <vector>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <dlfcn.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#include "Helper/Vector3.h"  
#import "Helper/SecurityCheck.h"
#import <substrate.h> 
#include "hook/hook.h"
#include <sstream>
#include <cstring>
#include <cstdlib>
#import <sys/sysctl.h>
#include <cstdio>
#include <cstdint>

#include <cinttypes>
#include <cerrno>
#include <cctype>
#import <CommonCrypto/CommonCrypto.h>
#import "Esp/CaptainHook.h"
#include "oxorany/oxorany_include.h"
#import "Helper/Mem.h"
#include "font.h"
#import "Helper/Vector3.h"
#import "Helper/Vector2.h"
#import "Helper/Quaternion.h"
#import "Helper/Monostring.h"
#include "Helper/font.h"
#include "Helper/data.h"
#include "Helper/Obfuscate.h"
#import "menuUIKIT/drawfunc.h"
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <unistd.h>

#include <string.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define patch_NULL(a, b) \
    vm(ENCRYPTOFFSET(a), strtoul(ENCRYPTHEX(b), nullptr, 0))
#define patch(a, b) \
    vm_unity(ENCRYPTOFFSET(a), strtoul(ENCRYPTHEX(b), nullptr, 0))

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale


bool Guest(void* _this) { 
    return true; 
}

bool SetHighFPS(void* _this) { 
    return true; 
}
static const NSInteger kFeatureButtonBaseTag = 88800;
static const NSInteger kGhostButtonTag = 88801;
static const NSInteger kTeleVIPButtonTag = 88802;
static const NSInteger kUndergroundButtonTag = 88803;
static const NSInteger kAITelekillButtonTag = 88804;
static const NSInteger kNinjaRunButtonTag = 88805;
static const NSInteger kFlyAlturaButtonTag = 88806;
static const NSInteger kFlyNormalButtonTag = 88807;
static const NSInteger kSavePosButtonTag = 88808;
static const NSInteger kClearAntiuButtonTag = 88809;
static const NSInteger kMagnetKillButtonTag = 88810;

// Extern declarations for color variables from func.h
extern int ESPLineColor;
extern int ESPBoxColor;
extern int ESPSkeletonColor;
extern int ESPNameColor;
extern int AimbotFOVColor;
extern float AimbotFOVThickness;
extern int MenuColorTheme;
bool fmedkit = false;

bool StopGarenaLogs = false;
bool FastSwitch = false;

// Save Pos feature variables
bool testGhost = false;
bool func_ghost = false;

typedef NS_ENUM(NSInteger, MenuTab) {
    MenuTabAimbot = 0, 
    MenuTabESP, 
    MenuTabMSL, 
    MenuTabWeapons,
    MenuTabProfile
};
@interface ModMenuViewController () <UIGestureRecognizerDelegate>
- (void)saveSettingsToFile;
- (void)loadSettingsFromFile;
- (void)saveUIState;
- (void)loadUIState;
- (NSString *)settingsFilePath;
@property (nonatomic, strong) UIScrollView *sidebarScrollView;
@property (nonatomic, strong) UIView *sidebarView;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, assign) MenuTab currentTab;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, strong) NSMutableDictionary *checkboxStates;
@property (nonatomic, strong) NSTimer *fpsTimer;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) CGFloat currentFPS;
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIButton *headerButton;
@property (nonatomic, strong) UIView *tabSelectorPopup;
@property (nonatomic, strong) UIVisualEffectView *headerBlurView;
@property (nonatomic, strong) UIColor *currentThemeColor;
@property (nonatomic, assign) BOOL isUpdatingUI;
@property (nonatomic, assign) BOOL isChangingTab;
@property (nonatomic, assign) NSInteger currentLanguage; // 0 = English, 1 = Portuguese


@end

@implementation ModMenuViewController {
    UIView *floatingPanel;
    UIButton *themeToggle;
    UIButton *closeButton;
    CGFloat panelWidth;
}

// Helper to safely get LicenseManager (optional)
- (id)getLicenseManager {
    Class licenseClass = NSClassFromString(@"LicenseManager");
    if (licenseClass && [licenseClass respondsToSelector:@selector(shared)]) {
        return [licenseClass performSelector:@selector(shared)];
    }
    return nil;
}
    CGFloat panelHeight;
    BOOL isDarkMode;
    NSMutableDictionary *allCheckboxes;



// Global ModMenuViewController instance for theme access from ESP drawing
static ModMenuViewController *g_ModMenuInstance = nil;

// C function to set the global instance (called from viewDidLoad)
void SetModMenuInstance(ModMenuViewController *instance) {
    g_ModMenuInstance = instance;
}

// C functions to get theme colors for ESP drawing
UIColor* GetThemeAccentColor(void) {
    if (g_ModMenuInstance && [g_ModMenuInstance respondsToSelector:@selector(accentColor)]) {
        return [g_ModMenuInstance accentColor];
    }
    // Fallback to red theme
    return [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
}

UIColor* GetThemeTextColor(void) {
    if (g_ModMenuInstance && [g_ModMenuInstance respondsToSelector:@selector(textColor)]) {
        return [g_ModMenuInstance textColor];
    }
    // Fallback to white
    return [UIColor whiteColor];
}

UIColor* GetThemeGlowColor(void) {
    if (g_ModMenuInstance && [g_ModMenuInstance respondsToSelector:@selector(glowColor)]) {
        return [g_ModMenuInstance glowColor];
    }
    // Fallback
    return [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.7];
}

#pragma mark - Global Sizing Constants

static const CGFloat kSidebarWidth = 70;
static const CGFloat kTabIconSize = 48;
static const CGFloat kTabIconImageSize = 28;
static const CGFloat kTabSpacing = 8;
static const CGFloat kPillHeight = 50;
static const CGFloat kPillSpacing = 7;
static const CGFloat kContentPadding = 10;
static const CGFloat kContentTopInset = 5;
static const CGFloat kContentBottomInset = 10;
static const CGFloat kSeparatorPadding = 25;





void secureCrash() {
    volatile char *ptr = (char *)0x1;
    *ptr = 0xFF;
}


void switchfast (void* _this) {

    return;
}


float fastmedkit(void* _this) {
    return 9.0;
}









#pragma mark - Monite-style Helper: Diagonal Mask

static void applyDiagonalMask(UIView *view, CGFloat cut) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat w = view.bounds.size.width;
        CGFloat h = view.bounds.size.height;
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(cut, 0)];
        [path addLineToPoint:CGPointMake(w, 0)];
        [path addLineToPoint:CGPointMake(w, h - cut)];
        [path addLineToPoint:CGPointMake(w - cut, h)];
        [path addLineToPoint:CGPointMake(0, h)];
        [path addLineToPoint:CGPointMake(0, cut)];
        [path closePath];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = path.CGPath;
        view.layer.mask = mask;
    });
}

#pragma mark - Colors

- (UIColor *)backgroundColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:11/255.0 green:14/255.0 blue:21/255.0 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    }
}

- (UIColor *)sidebarColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:11/255.0 green:14/255.0 blue:21/255.0 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.92 green:0.94 blue:0.97 alpha:1.0];
    }
}

- (UIColor *)itemBackground {
    if (isDarkMode) {
        return [UIColor colorWithRed:25/255.0 green:32/255.0 blue:40/255.0 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.88 green:0.90 blue:0.94 alpha:1.0];
    }
}

- (UIColor *)headerColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:6/255.0 green:9/255.0 blue:14/255.0 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.84 green:0.87 blue:0.92 alpha:1.0];
    }
}

- (UIColor *)dividerColor {
    if (isDarkMode) {
        return [UIColor colorWithRed:26/255.0 green:29/255.0 blue:36/255.0 alpha:1.0];
    } else {
        return [UIColor colorWithRed:0.78 green:0.82 blue:0.88 alpha:1.0];
    }
}

- (UIColor *)textColor {
    return isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
}

- (UIColor *)secondaryTextColor {
    return [UIColor colorWithWhite:isDarkMode ? 0.65 : 0.35 alpha:1.0];
}

- (UIColor *)accentColor {
    switch (MenuColorTheme) {
        case 0: return [UIColor colorWithRed:1.0  green:0.2  blue:0.2  alpha:1.0]; // Red
        case 1: return [UIColor colorWithRed:0.2  green:0.5  blue:1.0  alpha:1.0]; // Blue
        case 2: return [UIColor colorWithRed:0.2  green:1.0  blue:0.2  alpha:1.0]; // Green
        case 3: return [UIColor colorWithRed:1.0  green:0.4  blue:0.8  alpha:1.0]; // Pink
        default: return [UIColor colorWithRed:1.0 green:0.2  blue:0.2  alpha:1.0];
    }
}

- (UIColor *)pillColor {
    return [self itemBackground];
}

- (UIColor *)checkboxOffColor {
    return isDarkMode ?
        [UIColor colorWithRed:25/255.0 green:32/255.0 blue:40/255.0 alpha:1.0] :
        [UIColor colorWithWhite:0.75 alpha:1.0];
}

- (UIColor *)glowColor {
    return [[self accentColor] colorWithAlphaComponent:0.6];
}

#pragma mark - UI State Persistence

- (void)saveUIState {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:self.currentTab forKey:@"DuckdzCurrentTab"];
    [d setBool:isDarkMode forKey:@"DuckdzDarkMode"];
    [d synchronize];
}

- (void)loadUIState {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"DuckdzCurrentTab"])
        self.currentTab = (MenuTab)[d integerForKey:@"DuckdzCurrentTab"];
    else
        self.currentTab = MenuTabESP;
    if ([d objectForKey:@"DuckdzDarkMode"])
        isDarkMode = [d boolForKey:@"DuckdzDarkMode"];
    else
        isDarkMode = YES;
    if ([d objectForKey:@"ModMenuLanguage"])
        self.currentLanguage = [d integerForKey:@"ModMenuLanguage"];
    else
        self.currentLanguage = 0;
}

#pragma mark - Settings File Management

- (NSString *)settingsFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:@"menu_settings.txt"];
}

- (void)saveSettingsToFile {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"Enable=%d\n",           Vars.Enable ? 1 : 0];
    [s appendFormat:@"Box=%d\n",              Vars.Box ? 1 : 0];
    [s appendFormat:@"Lines=%d\n",            Vars.lines ? 1 : 0];
    [s appendFormat:@"Skeleton=%d\n",         Vars.Skeleton ? 1 : 0];
    [s appendFormat:@"Distance=%d\n",         Vars.Distance ? 1 : 0];
    [s appendFormat:@"Name=%d\n",             Vars.Name ? 1 : 0];
    [s appendFormat:@"EnemyCount=%d\n",       Vars.enemycount ? 1 : 0];
    [s appendFormat:@"Glow=%d\n",             Vars.Glow ? 1 : 0];
    [s appendFormat:@"TargetPriority=%d\n",   Vars.TargetPriority];
    [s appendFormat:@"Aimbot=%d\n",           Vars.Aimbot ? 1 : 0];
    [s appendFormat:@"Aimsilent=%d\n",        Vars.Aimsilent69 ? 1 : 0];
    [s appendFormat:@"Show Extra Animation=%d\n", Vars.ShowEn ? 1 : 0];
    [s appendFormat:@"RateOfFire=%d\n",       Vars.rateoffire ? 1 : 0];
    [s appendFormat:@"AimFov=%.2f\n",         Vars.AimFov];
    [s appendFormat:@"AimWhen=%d\n",          Vars.AimWhen];
    [s appendFormat:@"Target=%d\n",           (int)Vars.Target];
    [s appendFormat:@"SpeedHack=%d\n",        SpeedHack ? 1 : 0];
    [s appendFormat:@"UpPlayer=%d\n",         Vars.UpPlayer ? 1 : 0];
    [s appendFormat:@"Telekill=%d\n",         Vars.Telekill ? 1 : 0];
    [s appendFormat:@"UndergroundKill2=%d\n", Vars.UndergroundKill2 ? 1 : 0];
    [s appendFormat:@"NinjaRun=%d\n",         Vars.NinjaRun ? 1 : 0];
    [s appendFormat:@"NinjaRunSlow=%d\n",     Vars.NinjaRun_Slow ? 1 : 0];
    [s appendFormat:@"NinjaRunFast=%d\n",     Vars.NinjaRun_Fast ? 1 : 0];
    [s appendFormat:@"Guest2=%d\n",           Guest2 ? 1 : 0];
    [s appendFormat:@"HighFPS=%d\n",          HighFPS ? 1 : 0];
    [s appendFormat:@"StreamMode=%d\n",       StreamMode ? 1 : 0];
    [s appendFormat:@"FastSwitch=%d\n",       FastSwitch ? 1 : 0];
    [s appendFormat:@"IgnoreBot=%d\n",        IgnoreBot ? 1 : 0];
    [s appendFormat:@"IgnoreKnocked2=%d\n",   IgnoreKnocked2 ? 1 : 0];
    [s appendFormat:@"StopLogs=%d\n",         StopGarenaLogs ? 1 : 0];
    NSError *err = nil;
    [s writeToFile:[self settingsFilePath] atomically:YES encoding:NSUTF8StringEncoding error:&err];
}

- (void)loadSettingsFromFile {
    NSString *fp = [self settingsFilePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fp]) return;
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:fp encoding:NSUTF8StringEncoding error:&err];
    if (err || !content) return;
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSArray *parts = [line componentsSeparatedByString:@"="];
        if (parts.count == 2) {
            settings[[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]] =
                [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }
    if (settings[@"Enable"])          Vars.Enable = [settings[@"Enable"] intValue] == 1;
    if (settings[@"Box"])             Vars.Box = [settings[@"Box"] intValue] == 1;
    if (settings[@"Lines"])           Vars.lines = [settings[@"Lines"] intValue] == 1;
    if (settings[@"Skeleton"])        Vars.Skeleton = [settings[@"Skeleton"] intValue] == 1;
    if (settings[@"Distance"])        Vars.Distance = [settings[@"Distance"] intValue] == 1;
    if (settings[@"Name"])            Vars.Name = [settings[@"Name"] intValue] == 1;
    if (settings[@"EnemyCount"])      Vars.enemycount = [settings[@"EnemyCount"] intValue] == 1;
    if (settings[@"Glow"])            Vars.Glow = [settings[@"Glow"] intValue] == 1;
    if (settings[@"TargetPriority"])  Vars.TargetPriority = [settings[@"TargetPriority"] intValue];
    if (settings[@"Aimbot"])          Vars.Aimbot = [settings[@"Aimbot"] intValue] == 1;
    if (settings[@"Aimsilent"])       Vars.Aimsilent69 = [settings[@"Aimsilent"] intValue] == 1;
    if (settings[@"AimKill"])         Vars.playertakedamage2T = [settings[@"AimKill"] intValue] == 1;
    if (settings[@"RateOfFire"])      Vars.rateoffire = [settings[@"RateOfFire"] intValue] == 1;
    if (settings[@"AimFov"])          Vars.AimFov = [settings[@"AimFov"] floatValue];
    if (settings[@"AimWhen"])         Vars.AimWhen = [settings[@"AimWhen"] intValue];
    if (settings[@"Target"])          Vars.Target = (AimTarget)[settings[@"Target"] intValue];
    if (settings[@"SpeedHack"])       SpeedHack = [settings[@"SpeedHack"] intValue] == 1;
    if (settings[@"UpPlayer"])        Vars.UpPlayer = [settings[@"UpPlayer"] intValue] == 1;
    if (settings[@"Telekill"])        Vars.Telekill = [settings[@"Telekill"] intValue] == 1;
    if (settings[@"UndergroundKill2"]) Vars.UndergroundKill2 = [settings[@"UndergroundKill2"] intValue] == 1;
    if (settings[@"NinjaRun"])        Vars.NinjaRun = [settings[@"NinjaRun"] intValue] == 1;
    if (settings[@"NinjaRunSlow"])    Vars.NinjaRun_Slow = [settings[@"NinjaRunSlow"] intValue] == 1;
    if (settings[@"NinjaRunFast"])    Vars.NinjaRun_Fast = [settings[@"NinjaRunFast"] intValue] == 1;
    if (settings[@"Guest2"])          Guest2 = [settings[@"Guest2"] intValue] == 1;
    if (settings[@"HighFPS"])         HighFPS = [settings[@"HighFPS"] intValue] == 1;
    if (settings[@"StreamMode"])      StreamMode = [settings[@"StreamMode"] intValue] == 1;
    if (settings[@"FastSwitch"])      FastSwitch = [settings[@"FastSwitch"] intValue] == 1;
    if (settings[@"IgnoreBot"])       IgnoreBot = [settings[@"IgnoreBot"] intValue] == 1;
    if (settings[@"IgnoreKnocked2"])  IgnoreKnocked2 = [settings[@"IgnoreKnocked2"] intValue] == 1;
    if (settings[@"StopLogs"])        StopGarenaLogs = [settings[@"StopLogs"] intValue] == 1;
}

#pragma mark - Switch handlers (unchanged game logic)

- (void)undergroundSwitchChanged:(UISwitch *)sender { Vars.invisible = sender.on; }
- (void)magnetKillSwitchChanged:(UISwitch *)sender   { Vars.MagnetKill = sender.on; }
- (void)teleVIPSwitchChanged:(UISwitch *)sender      { Vars.TeleVIP = sender.on; }
- (void)aiTelekillSwitchChanged:(UISwitch *)sender   { Vars.AITelekill = sender.on; }
- (void)ninjaRunSwitchChanged:(UISwitch *)sender     { Vars.NinjaRun = sender.on; }
- (void)ghostSwitchChanged:(UISwitch *)sender        { Vars.EnableGhost = sender.on; }
- (void)flyAlturaSwitchChanged:(UISwitch *)sender    { flyalt = sender.on; }
- (void)flyNormalSwitchChanged:(UISwitch *)sender    { @try { Vars.fly = sender.on; } @catch (NSException *e) {} }

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    panelWidth  = 425;
    panelHeight = 340;
    isDarkMode  = YES;
    self.currentTab = MenuTabESP;

    [self loadUIState];

    // Force UIKit to use our custom theme instead of system dark/light mode
    // This prevents UIKit from auto-applying dark backgrounds when changing tabs
    self.overrideUserInterfaceStyle = isDarkMode ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;

    SetModMenuInstance(self);

    self.tabButtons    = [NSMutableArray array];
    self.checkboxStates = [NSMutableDictionary dictionary];
    allCheckboxes       = [NSMutableDictionary dictionary];
    self.frameCount    = 0;
    self.currentFPS    = 0;

    [self setupMainView];
    [self buildFloatingPanel];

    [self setupDisplayLink];
    [self startFPSTimer];
    [self animatePanelEntrance];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(screenCaptureStatusChanged:)
               name:UIScreenCapturedDidChangeNotification
             object:nil];

    if (StreamMode) {
        SetStreamMode(YES);
        if (floatingPanel) UpdateStreamProtectionForView(floatingPanel);
        if (self.view)     UpdateStreamProtectionForView(self.view);
    }
}

- (void)startFPSTimer {
    self.fpsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        self.currentFPS = self.frameCount;
        self.frameCount = 0;
        if (self.fpsLabel) self.fpsLabel.text = [NSString stringWithFormat:@"%.0f FPS", self.currentFPS];
        if (self.timeLabel) {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            [f setDateFormat:@"HH:mm:ss"];
            self.timeLabel.text = [f stringFromDate:[NSDate date]];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated  { [super viewWillAppear:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; }
- (void)dealloc {}

- (void)setupMainView {
    self.view = [[PassthroughView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.multipleTouchEnabled = YES;
}

- (void)setupDisplayLink {
    CADisplayLink *dl = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    [dl addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setupGestureRecognizers {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleOutsideTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
}

- (void)updateFrame {
    get_players();
    aimbot();
    game_sdk->init();
    boxUIKIT();
    espUIKIT();
    distanceUIKIT();
    nameUIKIT();
    skeleton();
    enemyCountUIKIT();
    SpeedAuto();
    if (Vars.Glow) renderGlow();
    Vars.isAimFov = Vars.AimFov > 0;
    self.frameCount++;
}

#pragma mark - Build Floating Panel (Monite Style)

- (void)buildFloatingPanel {
    CGPoint saved = [self loadPanelPosition];

    floatingPanel = [[UIView alloc] initWithFrame:CGRectMake(saved.x, saved.y, panelWidth, panelHeight)];
    floatingPanel.backgroundColor = [self backgroundColor];
    floatingPanel.clipsToBounds = YES;

    // Diagonal cut corners like monite
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat cut = 16, w = panelWidth, h = panelHeight;
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(cut, 0)];
        [p addLineToPoint:CGPointMake(w, 0)];
        [p addLineToPoint:CGPointMake(w, h - cut)];
        [p addLineToPoint:CGPointMake(w - cut, h)];
        [p addLineToPoint:CGPointMake(0, h)];
        [p addLineToPoint:CGPointMake(0, cut)];
        [p closePath];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = p.CGPath;
        floatingPanel.layer.mask = mask;
    });

    [self.view addSubview:floatingPanel];

    // Sidebar (113px wide) — dark like monite
    CGFloat sidebarW = 113;
    self.sidebarScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, sidebarW, panelHeight)];
    self.sidebarScrollView.backgroundColor = [self sidebarColor];
    self.sidebarScrollView.showsVerticalScrollIndicator = NO;
    [floatingPanel addSubview:self.sidebarScrollView];

    self.sidebarView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.sidebarScrollView addSubview:self.sidebarView];

    // Vertical divider
    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(sidebarW, 0, 1, panelHeight)];
    div.backgroundColor = [self dividerColor];
    div.tag = 3000;
    [floatingPanel addSubview:div];

    // Content area
    self.contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(sidebarW + 1, 0, panelWidth - sidebarW - 1, panelHeight)];
    self.contentScrollView.backgroundColor = [self backgroundColor];
    self.contentScrollView.showsVerticalScrollIndicator = YES;
    self.contentScrollView.indicatorStyle = isDarkMode ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [floatingPanel addSubview:self.contentScrollView];

    self.contentContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.contentScrollView.frame.size.width, panelHeight)];
    self.contentContainer.backgroundColor = UIColor.clearColor;
    [self.contentScrollView addSubview:self.contentContainer];

    // Pan gesture on content header area
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [floatingPanel addGestureRecognizer:pan];

    [self buildSidebarTabs];
    [self buildHeader];
    [self reloadContentForTab:self.currentTab animated:NO];
    [self setupGestureRecognizers];
}

#pragma mark - Sidebar Tabs (Monite style with accent bar)

- (void)buildSidebarTabs {
    NSArray *icons = @[@"scope", @"eye.fill", @"gamecontroller.fill", @"wrench.and.screwdriver.fill", @"person.fill"];
    NSArray *labels = @[@"Aimbot", @"ESP", @"MSL", @"Weapons", @"Profile"];

    CGFloat itemH = 56, spacing = 8, itemW = 110;
    CGFloat totalH = spacing + icons.count * (itemH + spacing);

    self.sidebarView.frame = CGRectMake(0, 0, 113, totalH);
    self.sidebarScrollView.contentSize = CGSizeMake(113, totalH);

    [self.tabButtons removeAllObjects];
    for (UIView *v in self.sidebarView.subviews) [v removeFromSuperview];

    for (int i = 0; i < (int)icons.count; i++) {
        BOOL selected = (i == self.currentTab);
        CGFloat y = spacing + i * (itemH + spacing);

        UIView *item = [[UIView alloc] initWithFrame:CGRectMake(0, y, itemW, itemH)];
        item.tag = 1000 + i;

        UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(spacing, 0, itemW - spacing * 2, itemH)];
        bg.tag = 2000;
        bg.backgroundColor = selected ?
            (isDarkMode
                ? [UIColor colorWithRed:6/255.0 green:9/255.0 blue:14/255.0 alpha:1.0]
                : [UIColor colorWithRed:0.82 green:0.85 blue:0.90 alpha:1.0]) :
            UIColor.clearColor;
        bg.clipsToBounds = YES;
        if (selected) applyDiagonalMask(bg, 8);
        [item addSubview:bg];

        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [[UIImage systemImageNamed:icons[i]] imageByApplyingSymbolConfiguration:cfg];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.frame = CGRectMake((bg.frame.size.width - 18) / 2, 8, 18, 18);
        iv.contentMode = UIViewContentModeScaleAspectFit;
        // Light mode: selected = accentColor text, unselected = medium gray
        // Dark mode: selected = white, unselected = gray
        UIColor *iconTint;
        if (selected) {
            iconTint = isDarkMode ? UIColor.whiteColor : [self accentColor];
        } else {
            iconTint = [UIColor colorWithWhite:isDarkMode ? 0.55 : 0.40 alpha:1.0];
        }
        iv.tintColor = iconTint;
        iv.tag = 3000;
        [bg addSubview:iv];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(iv.frame) + 3, bg.frame.size.width, 14)];
        lbl.text = labels[i];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        lbl.textColor = iconTint;
        lbl.tag = 4000;
        [bg addSubview:lbl];

        if (selected) {
            UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(bg.frame.size.width - 3, 0, 3, itemH)];
            bar.backgroundColor = [self accentColor];
            bar.tag = 5000;
            [bg addSubview:bar];
        }

        UIButton *btn = [[UIButton alloc] initWithFrame:item.bounds];
        btn.backgroundColor = UIColor.clearColor;
        btn.tag = i;
        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [item addSubview:btn];

        [self.sidebarView addSubview:item];
        [self.tabButtons addObject:btn];
    }
}

#pragma mark - Header (Monite style: icon + tab title + desc + dark/light toggle + close)

- (void)buildHeader {
    // Remove old header
    for (UIView *v in self.contentContainer.subviews) {
        if (v.tag == 9999) [v removeFromSuperview];
    }

    CGFloat padding = 12, hH = 40, cW = self.contentScrollView.frame.size.width;

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(padding, padding, cW - padding * 2, hH)];
    header.tag = 9999;
    header.backgroundColor = [self headerColor];
    header.clipsToBounds = YES;
    applyDiagonalMask(header, 10);
    [self.contentContainer addSubview:header];

    // Tab icon + title + desc
    NSArray *tabIcons  = @[@"scope", @"eye.fill", @"gamecontroller.fill", @"wrench.and.screwdriver.fill", @"person.fill"];
    NSArray *tabTitles = @[@"AIMBOT", @"ESP", @"MSL", @"WEAPONS", @"PROFILE"];
    NSArray *tabDescs  = @[
        @"Automatically target enemies.",
        @"See where the enemies are.",
        @"Extra gameplay features.",
        @"Weapon behavior tweaks.",
        @"Device & menu settings."
    ];
    NSInteger tab = self.currentTab;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:tabIcons[tab]] imageByApplyingSymbolConfiguration:cfg]];
    iconView.tintColor = [self accentColor];
    iconView.frame = CGRectMake(10, (hH - 14) / 2, 14, 14);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [header addSubview:iconView];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = tabTitles[tab];
    titleLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    titleLbl.textColor = [self accentColor];
    [titleLbl sizeToFit];
    titleLbl.frame = CGRectMake(CGRectGetMaxX(iconView.frame) + 6, 0, titleLbl.frame.size.width, hH);
    [header addSubview:titleLbl];

    CGFloat divX = CGRectGetMaxX(titleLbl.frame) + 8;
    UIView *vDiv = [[UIView alloc] initWithFrame:CGRectMake(divX, 10, 1, hH - 20)];
    vDiv.backgroundColor = [self dividerColor];
    [header addSubview:vDiv];

    // Buttons: theme toggle + close (right side of header)
    CGFloat btnSz = 26;
    CGFloat closeX = header.frame.size.width - btnSz - 6;
    CGFloat themeX = closeX - btnSz - 6;

    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(closeX, (hH - btnSz) / 2, btnSz, btnSz)];
    closeBtn.backgroundColor = [self itemBackground];
    applyDiagonalMask(closeBtn, 5);
    UIImageSymbolConfiguration *smCfg = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold];
    [closeBtn setImage:[[UIImage systemImageNamed:@"xmark"] imageByApplyingSymbolConfiguration:smCfg] forState:UIControlStateNormal];
    closeBtn.tintColor = [self accentColor];
    [closeBtn addTarget:self action:@selector(animateClose) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    self.headerButton = closeBtn; // reuse property for reference

    themeToggle = [[UIButton alloc] initWithFrame:CGRectMake(themeX, (hH - btnSz) / 2, btnSz, btnSz)];
    themeToggle.backgroundColor = [self itemBackground];
    applyDiagonalMask(themeToggle, 5);
    [themeToggle setImage:[[UIImage systemImageNamed:isDarkMode ? @"moon.fill" : @"sun.max.fill"] imageByApplyingSymbolConfiguration:smCfg] forState:UIControlStateNormal];
    themeToggle.tintColor = [self accentColor];
    [themeToggle addTarget:self action:@selector(toggleTheme) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:themeToggle];
    closeButton = themeToggle; // reuse for color update

    // Scrolling desc label
    CGFloat descX = divX + 8;
    CGFloat descW = themeX - descX - 6;
    UILabel *descLbl = [[UILabel alloc] initWithFrame:CGRectMake(descX, 0, descW, hH)];
    descLbl.text = tabDescs[tab];
    descLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    descLbl.textColor = [self secondaryTextColor];
    descLbl.lineBreakMode = NSLineBreakByClipping;
    descLbl.numberOfLines = 1;
    [header addSubview:descLbl];

    // Animate scroll if text too long
    CGSize sz = [descLbl sizeThatFits:CGSizeMake(CGFLOAT_MAX, hH)];
    if (sz.width > descW) {
        descLbl.frame = CGRectMake(descX, 0, sz.width, hH);
        CGFloat dist = sz.width - descW;
        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        anim.values = @[@0, @0, @(-dist), @(-dist), @0];
        anim.keyTimes = @[@0.0, @0.1, @0.5, @0.9, @1.0];
        anim.duration = 8.0;
        anim.repeatCount = HUGE_VALF;
        [descLbl.layer addAnimation:anim forKey:@"scrollDesc"];
    }
}

#pragma mark - Tab Switching

- (void)tabButtonTapped:(UIButton *)sender {
    if (self.isChangingTab) return;
    MenuTab sel = (MenuTab)sender.tag;
    if (sel == self.currentTab) return;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    self.currentTab = sel;
    [self saveUIState];
    [self buildSidebarTabs];
    [self reloadContentForTab:sel animated:YES];
}

- (void)updateSidebarForTab:(MenuTab)tab {
    [self buildSidebarTabs];
}

- (void)updateHeaderForTab:(MenuTab)tab {
    [self buildHeader];
}

- (void)loadTabContent:(MenuTab)tab {
    [self reloadContentForTab:tab animated:YES];
}

- (void)reloadContentForTab:(MenuTab)tab animated:(BOOL)animated {
    if (self.isChangingTab) return;
    self.isChangingTab = YES;

    void (^doLoad)(void) = ^{
        for (UIView *sv in self.contentContainer.subviews) [sv removeFromSuperview];
        [self buildHeader];

        CGFloat headerBottom = 40 + 12 + 12; // header height + top padding + gap
        CGFloat cW = self.contentScrollView.frame.size.width;
        CGFloat y = headerBottom;

        switch (tab) {
            case MenuTabAimbot:  y = [self buildAimbotContent:y width:cW]; break;
            case MenuTabESP:     y = [self buildESPContent:y width:cW]; break;
            case MenuTabMSL:     y = [self buildMSLContent:y width:cW]; break;
            case MenuTabWeapons: y = [self buildWeaponsContent:y width:cW]; break;
            case MenuTabProfile: y = [self buildProfileContent:y width:cW]; break;
        }

        self.contentContainer.frame = CGRectMake(0, 0, cW, y + 12);
        self.contentScrollView.contentSize = CGSizeMake(cW, y + 12);
        self.contentContainer.transform = animated ? CGAffineTransformMakeTranslation(0, -8) : CGAffineTransformIdentity;

        [UIView animateWithDuration:animated ? 0.25 : 0
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.5
                            options:0
                         animations:^{
            self.contentContainer.alpha = 1.0;
            self.contentContainer.transform = CGAffineTransformIdentity;
        } completion:^(BOOL f) {
            self.isChangingTab = NO;
        }];
    };

    if (animated) {
        self.contentContainer.alpha = 0;
        [UIView animateWithDuration:0.12 animations:^{
            self.contentContainer.alpha = 0;
        } completion:^(BOOL f) { doLoad(); }];
    } else {
        doLoad();
    }
}

#pragma mark - Monite-style UI Components

// Checkbox row (monite style with diagonal box)
- (CGFloat)addMoniteCheckbox:(NSString *)text
                    valueRef:(BOOL *)ref
                     warning:(BOOL)warn
                          atY:(CGFloat)y
                       parent:(UIView *)parent {
    CGFloat pad = 14, rowH = 30, boxSz = 22;
    CGFloat rowW = parent.frame.size.width - pad * 2;

    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(pad, y, rowW, rowH)];
    [parent addSubview:row];

    CGFloat startX = 0;
    if (warn) {
        UIImageView *warnIV = [[UIImageView alloc] initWithFrame:CGRectMake(0, (rowH - 16) / 2, 16, 16)];
        warnIV.image = [[UIImage systemImageNamed:@"exclamationmark.triangle.fill"] imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]];
        warnIV.tintColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.1 alpha:1.0];
        [row addSubview:warnIV];
        startX = 22;
    }

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(startX, (rowH - boxSz) / 2, boxSz, boxSz)];
    box.backgroundColor = *ref ? [self accentColor] : [self checkboxOffColor];
    box.clipsToBounds = YES;
    box.tag = 8000;
    applyDiagonalMask(box, 4);
    [row addSubview:box];

    UIImageView *check = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, boxSz - 8, boxSz - 8)];
    check.image = [[UIImage systemImageNamed:@"checkmark"] imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]];
    check.tintColor = UIColor.whiteColor;
    check.hidden = !(*ref);
    check.alpha = *ref ? 1.0 : 0.0;
    check.tag = 999;
    [box addSubview:check];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(box.frame) + 10, 0, rowW - CGRectGetMaxX(box.frame) - 10, rowH)];
    lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithWhite:isDarkMode ? 0.85 : 0.2 alpha:1.0];
    [row addSubview:lbl];

    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(startX, 0, rowW - startX, rowH)];
    btn.backgroundColor = UIColor.clearColor;

    // Store ref as associated object
    objc_setAssociatedObject(btn, "boolRef", [NSValue valueWithPointer:ref], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(btn, "boxView", box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(btn, "checkView", check, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [btn addTarget:self action:@selector(moniteCheckboxTapped:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];

    return y + rowH + 2;
}

- (void)moniteCheckboxTapped:(UIButton *)btn {
    NSValue *refVal = objc_getAssociatedObject(btn, "boolRef");
    UIView *box     = objc_getAssociatedObject(btn, "boxView");
    UIImageView *check = objc_getAssociatedObject(btn, "checkView");
    if (!refVal) return;

    BOOL *ref = (BOOL *)[refVal pointerValue];
    BOOL newVal = !(*ref);
    *ref = newVal;

    UIColor *endColor = newVal ? [self accentColor] : [self checkboxOffColor];
    [UIView animateWithDuration:0.22 animations:^{ box.backgroundColor = endColor; }];

    if (newVal) {
        check.hidden = NO;
        check.alpha = 0;
        [UIView animateWithDuration:0.22 animations:^{ check.alpha = 1.0; }];
    } else {
        [UIView animateWithDuration:0.22 animations:^{ check.alpha = 0; } completion:^(BOOL f) { check.hidden = YES; }];
    }

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    // Handle side-effects for features that need hooking
    if (ref == &StreamMode) {
        SetStreamMode(newVal);
        if (floatingPanel) UpdateStreamProtectionForView(floatingPanel);
        if (self.view)     UpdateStreamProtectionForView(self.view);
        if (newVal)        reapplyStreamModeToAllESP();
    } else if (ref == &FastSwitch) {
        static bool wasswitch = false;
        if (newVal) {
            void *addr[] = { (void *)getRealOffset(0x1051467BC) };
            void *func[] = { (void *)switchfast };
            Zexis(addr, func, 1);
            wasswitch = true;
        } else {
            if (wasswitch) { ZexisUnhook((void *)switchfast); wasswitch = false; }
        }
    } else if (ref == &Guest2) {
        static bool wasGuestHooked = false;
        if (newVal) {
            void *addr[] = { (void *)getRealOffset(0x10126E688) };
            void *func[] = { (void *)Guest };
            Zexis(addr, func, 1);
            wasGuestHooked = true;
        } else {
            if (wasGuestHooked) { ZexisUnhook((void *)Guest); wasGuestHooked = false; }
        }
    } else if (ref == &fmedkit) {
        static bool wasfmHooked = false;
        if (newVal) {
            void *addr[] = { (void *)getRealOffset(0x1052C30C8) };
            void *func[] = { (void *)fastmedkit };
            Zexis(addr, func, 1);
            wasfmHooked = true;
        } else {
            if (wasfmHooked) { ZexisUnhook((void *)fastmedkit); wasfmHooked = false; }
        }
    }
}

// Monite-style action button with diagonal cut
- (CGFloat)addMoniteActionButton:(NSString *)text
                        iconName:(NSString *)iconName
                          action:(void(^)(void))action
                             atY:(CGFloat)y
                          parent:(UIView *)parent {
    CGFloat pad = 14, h = 34, w = parent.frame.size.width - pad * 2;

    UIView *btn = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w, h)];
    btn.backgroundColor = [self itemBackground];
    btn.clipsToBounds = YES;
    applyDiagonalMask(btn, 6);
    [parent addSubview:btn];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:cfg]];
    iv.tintColor = [self accentColor];
    iv.frame = CGRectMake(10, (h - 16) / 2, 16, 16);
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [btn addSubview:iv];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(34, 0, w - 50, h)];
    lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = [self secondaryTextColor];
    [btn addSubview:lbl];

    UIButton *tap = [[UIButton alloc] initWithFrame:btn.bounds];
    tap.backgroundColor = UIColor.clearColor;
    objc_setAssociatedObject(tap, "actionBlock", action, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [tap addTarget:self action:@selector(moniteActionTapped:) forControlEvents:UIControlEventTouchUpInside];
    [btn addSubview:tap];

    return y + h + 6;
}

- (void)moniteActionTapped:(UIButton *)sender {
    void (^block)(void) = objc_getAssociatedObject(sender, "actionBlock");
    UIView *container = sender.superview;

    [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:0 animations:^{
        container.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.4 initialSpringVelocity:0.5 options:0 animations:^{
            container.transform = CGAffineTransformIdentity;
        } completion:nil];
        if (block) block();
    }];
}

// Monite-style slider
- (CGFloat)addMoniteSlider:(NSString *)text
                 valueRef:(float *)ref
                      min:(float)min
                      max:(float)max
                      atY:(CGFloat)y
                   parent:(UIView *)parent {
    CGFloat pad = 14, sliderW = parent.frame.size.width - pad * 2;
    CGFloat thumbR = 9.0, trackOff = 4.0, sliderH = 36;

    UILabel *sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, sliderW, 18)];
    NSString *labelText = [NSString stringWithFormat:@"%@  %.1f", text, *ref];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:labelText];
    NSRange r = [labelText rangeOfString:[NSString stringWithFormat:@"%.1f", *ref]];
    if (r.location != NSNotFound)
        [attr addAttribute:NSForegroundColorAttributeName value:[self accentColor] range:r];
    sliderLabel.attributedText = attr;
    sliderLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    sliderLabel.textColor = [self secondaryTextColor];
    [parent addSubview:sliderLabel];
    y += 22;

    UIView *sliderCont = [[UIView alloc] initWithFrame:CGRectMake(pad, y, sliderW, sliderH)];
    sliderCont.backgroundColor = UIColor.clearColor;
    [parent addSubview:sliderCont];

    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(thumbR - trackOff, sliderH / 2 - 1.5, sliderW - thumbR * 2 + trackOff * 2, 3)];
    track.backgroundColor = isDarkMode ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor colorWithWhite:0.75 alpha:1.0];
    track.layer.cornerRadius = 1.5;
    [sliderCont addSubview:track];

    UIView *fill = [[UIView alloc] initWithFrame:CGRectMake(track.frame.origin.x, track.frame.origin.y, 0, 3)];
    fill.backgroundColor = [self accentColor];
    fill.layer.cornerRadius = 1.5;
    [sliderCont addSubview:fill];

    UIView *thumb = [[UIView alloc] initWithFrame:CGRectMake(0, 0, thumbR * 2, thumbR * 2)];
    thumb.backgroundColor = UIColor.clearColor;
    thumb.layer.cornerRadius = thumbR;
    thumb.layer.borderColor = [self accentColor].CGColor;
    thumb.layer.borderWidth = 5.0;
    thumb.tag = 7001;
    [sliderCont addSubview:thumb];

    float pct = (*ref - min) / (max - min);
    CGFloat initX = track.frame.origin.x + pct * track.frame.size.width;
    thumb.center = CGPointMake(initX, sliderH / 2);
    fill.frame = CGRectMake(track.frame.origin.x, track.frame.origin.y, MAX(0, initX - track.frame.origin.x - thumb.layer.borderWidth), 3);

    void (^update)(float, BOOL) = ^(float val, BOOL anim) {
        float p2 = (val - min) / (max - min);
        CGFloat x2 = track.frame.origin.x + p2 * track.frame.size.width;
        void (^apply)(void) = ^{
            thumb.center = CGPointMake(x2, sliderH / 2);
            CGFloat fw = MAX(0, x2 - track.frame.origin.x - thumb.layer.borderWidth);
            fill.frame = CGRectMake(track.frame.origin.x, track.frame.origin.y, fw, 3);
        };
        anim ? [UIView animateWithDuration:0.18 animations:apply] : apply();

        NSString *newText = [NSString stringWithFormat:@"%@  %.1f", text, val];
        NSMutableAttributedString *a2 = [[NSMutableAttributedString alloc] initWithString:newText];
        NSRange r2 = [newText rangeOfString:[NSString stringWithFormat:@"%.1f", val]];
        if (r2.location != NSNotFound)
            [a2 addAttribute:NSForegroundColorAttributeName value:[self accentColor] range:r2];
        sliderLabel.attributedText = a2;
        sliderLabel.textColor = [self secondaryTextColor];
    };
    update(*ref, NO);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    pan.cancelsTouchesInView = NO;
    objc_setAssociatedObject(pan, "sliderCont", sliderCont, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pan, "track", track, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pan, "ref", [NSValue valueWithPointer:ref], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pan, "updateBlock", update, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(pan, "minVal", @(min), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(pan, "maxVal", @(max), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [pan addTarget:self action:@selector(moniteSliderPan:)];
    [thumb addGestureRecognizer:pan];

    return y + sliderH + 4;
}

- (void)moniteSliderPan:(UIPanGestureRecognizer *)pan {
    UIView *sc = objc_getAssociatedObject(pan, "sliderCont");
    UIView *track = objc_getAssociatedObject(pan, "track");
    NSValue *rv = objc_getAssociatedObject(pan, "ref");
    void (^update)(float, BOOL) = objc_getAssociatedObject(pan, "updateBlock");
    float mn = [objc_getAssociatedObject(pan, "minVal") floatValue];
    float mx = [objc_getAssociatedObject(pan, "maxVal") floatValue];
    if (!rv || !update) return;
    float *ref = (float *)[rv pointerValue];

    CGPoint loc = [pan locationInView:sc];
    float pct = (loc.x - track.frame.origin.x) / track.frame.size.width;
    pct = fminf(fmaxf(pct, 0), 1);
    float val = roundf((mn + pct * (mx - mn)) * 10) / 10.0f;
    *ref = val;
    update(val, YES);
}

// Segment control (monite style)
- (CGFloat)addMoniteSegment:(NSArray *)options
                       refI:(int *)ref
                        tag:(NSInteger)containerTag
                     tagBase:(NSInteger)tagBase
                        atY:(CGFloat)y
                     parent:(UIView *)parent {
    CGFloat pad = 14, h = 38, w = parent.frame.size.width - pad * 2;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w, h)];
    container.backgroundColor = [self itemBackground];
    container.layer.cornerRadius = h / 2;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = isDarkMode ?
        [[UIColor colorWithWhite:1.0 alpha:0.08] CGColor] :
        [[UIColor colorWithWhite:0.0 alpha:0.05] CGColor];
    container.tag = containerTag;
    [parent addSubview:container];

    CGFloat bW = (w - 8) / options.count;
    NSInteger cur = *ref;
    if (cur < 0 || cur >= (NSInteger)options.count) cur = 0;

    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(4 + bW * cur, 4, bW, h - 8)];
    indicator.backgroundColor = [self accentColor];
    indicator.layer.cornerRadius = (h - 8) / 2;
    indicator.tag = 9000 + containerTag;
    indicator.layer.shadowColor = [self glowColor].CGColor;
    indicator.layer.shadowRadius = 6;
    indicator.layer.shadowOpacity = 0.5;
    indicator.layer.shadowOffset = CGSizeZero;
    [container addSubview:indicator];

    for (int i = 0; i < (int)options.count; i++) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(4 + bW * i, 4, bW, h - 8)];
        btn.tag = tagBase + i;
        btn.backgroundColor = UIColor.clearColor;

        UILabel *lbl = [[UILabel alloc] initWithFrame:btn.bounds];
        lbl.text = options[i];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:12 weight:(i == cur) ? UIFontWeightBold : UIFontWeightMedium];
        lbl.textColor = (i == cur)
            ? UIColor.whiteColor  // Accent indicator is always dark enough for white text
            : [self secondaryTextColor];
        lbl.tag = 100;
        [btn addSubview:lbl];

        objc_setAssociatedObject(btn, "containerTag", @(containerTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "optCount", @(options.count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "refPtr", [NSValue valueWithPointer:ref], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "tagBase", @(tagBase), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [btn addTarget:self action:@selector(moniteSegmentTapped:) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:btn];
    }

    return y + h + 6;
}

- (void)moniteSegmentTapped:(UIButton *)sender {
    NSInteger cTag = [objc_getAssociatedObject(sender, "containerTag") integerValue];
    NSInteger cnt  = [objc_getAssociatedObject(sender, "optCount") integerValue];
    NSInteger base = [objc_getAssociatedObject(sender, "tagBase") integerValue];
    NSValue *rv    = objc_getAssociatedObject(sender, "refPtr");
    if (!rv) return;

    int *ref = (int *)[rv pointerValue];
    NSInteger newIdx = sender.tag - base;
    if (newIdx < 0 || newIdx >= cnt) return;
    *ref = (int)newIdx;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    // Menu color theme segment: rebuild UI with new accent color immediately
    if (cTag == 77020) {
        floatingPanel.layer.borderColor = [[self accentColor] colorWithAlphaComponent:0.3].CGColor;
        [self buildSidebarTabs];
        [self buildHeader];
        if (!self.isChangingTab)
            [self reloadContentForTab:self.currentTab animated:NO];
        return;
    }

    UIView *container = [self.contentContainer viewWithTag:cTag];
    if (!container) return;

    UIView *indicator = [container viewWithTag:9000 + cTag];
    CGFloat bW = (container.frame.size.width - 8) / cnt;
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:1.0 options:0 animations:^{
        indicator.frame = CGRectMake(4 + bW * newIdx, 4, bW, container.frame.size.height - 8);
    } completion:nil];

    for (int i = 0; i < cnt; i++) {
        UIButton *btn = [container viewWithTag:base + i];
        UILabel *lbl  = [btn viewWithTag:100];
        lbl.textColor = (i == newIdx)
            ? UIColor.whiteColor  // Accent indicator is always dark enough for white text
            : [self secondaryTextColor];
        lbl.font = [UIFont systemFontOfSize:12 weight:(i == newIdx) ? UIFontWeightBold : UIFontWeightMedium];
    }
}

// Section divider + label
- (CGFloat)addSectionDivider:(NSString *)title atY:(CGFloat)y parent:(UIView *)parent {
    CGFloat pad = 14, cW = parent.frame.size.width;
    y += 8;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(pad, y, cW - pad * 2, 1)];
    line.backgroundColor = [self dividerColor];
    [parent addSubview:line];
    y += 5;
    if (title.length > 0) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, cW - pad * 2, 16)];
        lbl.text = title;
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        lbl.textColor = [self secondaryTextColor];
        [parent addSubview:lbl];
        y += 20;
    }
    return y;
}

#pragma mark - Tab Content Builders

- (CGFloat)buildAimbotContent:(CGFloat)y width:(CGFloat)cW {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, cW, self.contentScrollView.frame.size.height - y)];
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = YES;
    [self.contentContainer addSubview:scroll];

    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cW, 1)];
    c.backgroundColor = UIColor.clearColor;
    [scroll addSubview:c];

    CGFloat cy = 6;
    cy = [self addMoniteCheckbox:@"Aimbot"         valueRef:&Vars.Aimbot       warning:NO  atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Aim Silent"     valueRef:&Vars.Aimsilent69  warning:YES atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Aim Kill"       valueRef:&Vars.playertakedamage2T warning:YES atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Ignore Bot"     valueRef:&IgnoreBot         warning:NO  atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Ignore Knocked" valueRef:&IgnoreKnocked2    warning:NO  atY:cy parent:c];

    cy = [self addSectionDivider:@"TRIGGER WHEN" atY:cy parent:c];
    cy = [self addMoniteSegment:@[@"Always", @"Firing", @"Scope"]
                           refI:&Vars.AimWhen tag:77001 tagBase:20000 atY:cy parent:c];

    cy = [self addSectionDivider:@"TARGET BONE" atY:cy parent:c];
    cy = [self addMoniteSegment:@[@"Head", @"Neck", @"Body"]
                           refI:(int*)&Vars.Target tag:77002 tagBase:30000 atY:cy parent:c];

    cy = [self addSectionDivider:@"PRIORITY" atY:cy parent:c];
    cy = [self addMoniteSegment:@[@"Closest", @"Low HP", @"Headshot"]
                           refI:&Vars.TargetPriority tag:77003 tagBase:31000 atY:cy parent:c];

    cy = [self addSectionDivider:@"FOV" atY:cy parent:c];
    cy = [self addMoniteSlider:@"FOV Radius" valueRef:&Vars.AimFov min:0 max:500 atY:cy parent:c];
    cy = [self addMoniteSlider:@"FOV Thickness" valueRef:&AimbotFOVThickness min:0.1 max:5.0 atY:cy parent:c];

    c.frame = CGRectMake(0, 0, cW, cy + 10);
    scroll.contentSize = c.frame.size;
    return y + scroll.frame.size.height;
}

- (CGFloat)buildESPContent:(CGFloat)y width:(CGFloat)cW {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, cW, self.contentScrollView.frame.size.height - y)];
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = YES;
    [self.contentContainer addSubview:scroll];

    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cW, 1)];
    c.backgroundColor = UIColor.clearColor;
    [scroll addSubview:c];

    CGFloat cy = 6;
    cy = [self addMoniteCheckbox:@"Enable ESP"     valueRef:&Vars.Enable    warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Box"        valueRef:&Vars.Box       warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Lines"      valueRef:&Vars.lines     warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Skeleton"   valueRef:&Vars.Skeleton  warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Health"     valueRef:&Vars.Health    warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Distance"   valueRef:&Vars.Distance  warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Name"       valueRef:&Vars.Name      warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"ESP Outline"    valueRef:&Vars.Outline   warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Enemy Count"    valueRef:&Vars.enemycount warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Glow Effect"    valueRef:&Vars.Glow      warning:NO atY:cy parent:c];

    cy = [self addSectionDivider:@"ESP COLORS" atY:cy parent:c];
    cy = [self addMoniteSegment:@[@"White", @"Red", @"Blue", @"Green", @"Pink"]
                           refI:&ESPLineColor tag:77010 tagBase:40000 atY:cy parent:c];

    c.frame = CGRectMake(0, 0, cW, cy + 10);
    scroll.contentSize = c.frame.size;
    return y + scroll.frame.size.height;
}

- (CGFloat)buildMSLContent:(CGFloat)y width:(CGFloat)cW {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, cW, self.contentScrollView.frame.size.height - y)];
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = YES;
    [self.contentContainer addSubview:scroll];

    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cW, 1)];
    c.backgroundColor = UIColor.clearColor;
    [scroll addSubview:c];

    CGFloat cy = 6;
    cy = [self addMoniteCheckbox:@"Speed Hack"    valueRef:&SpeedHack           warning:YES atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Up Player"     valueRef:&Vars.UpPlayer       warning:YES atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Telekill 8m"   valueRef:&Vars.Telekill       warning:YES atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Stream Mode"   valueRef:&StreamMode          warning:NO  atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Reset Guest"   valueRef:&Guest2              warning:NO  atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Fast Medkit"   valueRef:&fmedkit             warning:NO  atY:cy parent:c];

    c.frame = CGRectMake(0, 0, cW, cy + 10);
    scroll.contentSize = c.frame.size;
    return y + scroll.frame.size.height;
}

- (CGFloat)buildWeaponsContent:(CGFloat)y width:(CGFloat)cW {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, cW, self.contentScrollView.frame.size.height - y)];
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = YES;
    [self.contentContainer addSubview:scroll];

    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cW, 1)];
    c.backgroundColor = UIColor.clearColor;
    [scroll addSubview:c];

    CGFloat cy = 6;
    cy = [self addMoniteCheckbox:@"Fast Switch"   valueRef:&FastSwitch          warning:NO atY:cy parent:c];
    cy = [self addMoniteCheckbox:@"Rate of Fire"  valueRef:&Vars.rateoffire     warning:YES atY:cy parent:c];

    c.frame = CGRectMake(0, 0, cW, cy + 10);
    scroll.contentSize = c.frame.size;
    return y + scroll.frame.size.height;
}

- (CGFloat)buildProfileContent:(CGFloat)y width:(CGFloat)cW {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, cW, self.contentScrollView.frame.size.height - y)];
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = YES;
    [self.contentContainer addSubview:scroll];

    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cW, 1)];
    c.backgroundColor = UIColor.clearColor;
    [scroll addSubview:c];

    CGFloat cy = 6, pad = 14;

    // FPS / Time row
    CGFloat rowH = 28;
    UILabel *fpsL = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, 80, rowH)];
    fpsL.text = @"FPS";
    fpsL.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    fpsL.textColor = [self secondaryTextColor];
    [c addSubview:fpsL];
    UILabel *fpsV = [[UILabel alloc] initWithFrame:CGRectMake(pad + 90, cy, cW - pad * 2 - 90, rowH)];
    fpsV.text = [NSString stringWithFormat:@"%.0f FPS", self.currentFPS];
    fpsV.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBold];
    fpsV.textColor = [UIColor systemGreenColor];
    [c addSubview:fpsV];
    self.fpsLabel = fpsV;
    cy += rowH + 4;

    UILabel *timeL = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, 80, rowH)];
    timeL.text = @"Time";
    timeL.font = fpsL.font;
    timeL.textColor = [self secondaryTextColor];
    [c addSubview:timeL];
    UILabel *timeV = [[UILabel alloc] initWithFrame:CGRectMake(pad + 90, cy, cW - pad * 2 - 90, rowH)];
    timeV.text = @"00:00:00";
    timeV.font = fpsV.font;
    timeV.textColor = [self accentColor];
    [c addSubview:timeV];
    self.timeLabel = timeV;
    cy += rowH + 4;

    UILabel *devL = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, 80, rowH)];
    devL.text = @"Device";
    devL.font = fpsL.font;
    devL.textColor = [self secondaryTextColor];
    [c addSubview:devL];
    UILabel *devV = [[UILabel alloc] initWithFrame:CGRectMake(pad + 90, cy, cW - pad * 2 - 90, rowH)];
    devV.text = [[UIDevice currentDevice] model];
    devV.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    devV.textColor = [self textColor];
    [c addSubview:devV];
    cy += rowH + 4;

    UILabel *iosL = [[UILabel alloc] initWithFrame:CGRectMake(pad, cy, 80, rowH)];
    iosL.text = @"iOS";
    iosL.font = fpsL.font;
    iosL.textColor = [self secondaryTextColor];
    [c addSubview:iosL];
    UILabel *iosV = [[UILabel alloc] initWithFrame:CGRectMake(pad + 90, cy, cW - pad * 2 - 90, rowH)];
    iosV.text = [[UIDevice currentDevice] systemVersion];
    iosV.font = devV.font;
    iosV.textColor = [self textColor];
    [c addSubview:iosV];
    cy += rowH + 4;

    cy = [self addSectionDivider:@"MENU THEME" atY:cy parent:c];
    cy = [self addMoniteSegment:@[@"Red", @"Blue", @"Green", @"Pink"]
                           refI:&MenuColorTheme tag:77020 tagBase:50000 atY:cy parent:c];

    cy = [self addSectionDivider:@"ACTIONS" atY:cy parent:c];
    __weak __typeof__(self) weakSelf = self;
    cy = [self addMoniteActionButton:@"Save Settings" iconName:@"square.and.arrow.down" action:^{
        __strong __typeof__(weakSelf) s = weakSelf;
        [s saveSettingsToFile];
        [s saveUIState];
    } atY:cy parent:c];

    c.frame = CGRectMake(0, 0, cW, cy + 10);
    scroll.contentSize = c.frame.size;
    return y + scroll.frame.size.height;
}

#pragma mark - Theme Toggle

- (void)toggleTheme {
    if (self.isUpdatingUI) return;
    self.isUpdatingUI = YES;
    isDarkMode = !isDarkMode;
    [self saveUIState];

    // Sync UIKit interface style with our isDarkMode so new views created on tab switch
    // inherit the correct light/dark appearance instead of inheriting from the system
    self.overrideUserInterfaceStyle = isDarkMode ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    // Update all panel backgrounds immediately
    [UIView animateWithDuration:0.3 animations:^{
        floatingPanel.backgroundColor = [self backgroundColor];
        self.sidebarScrollView.backgroundColor = [self sidebarColor];
        self.contentScrollView.backgroundColor = [self backgroundColor];
        // Update vertical divider
        UIView *div = [floatingPanel viewWithTag:3000];
        if (div) div.backgroundColor = [self dividerColor];
    } completion:^(BOOL f) {
        self.isUpdatingUI = NO;
    }];

    // Flip icon
    [UIView transitionWithView:themeToggle duration:0.3 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
        [themeToggle setImage:[UIImage systemImageNamed:isDarkMode ? @"moon.fill" : @"sun.max.fill"] forState:UIControlStateNormal];
    } completion:nil];

    // Rebuild sidebar tabs with correct light/dark colors
    [self buildSidebarTabs];
    // Rebuild header
    [self buildHeader];
    // Reload current tab content
    if (!self.isChangingTab)
        [self reloadContentForTab:self.currentTab animated:NO];
}

#pragma mark - Drag / Gestures

- (void)handleDrag:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
    if (g.state == UIGestureRecognizerStateEnded)
        [self savePanelPosition:v.frame.origin];
}

- (void)handleOutsideTap:(UITapGestureRecognizer *)g {
    CGPoint loc = [g locationInView:self.view];
    if (!CGRectContainsPoint(floatingPanel.frame, loc))
        [self animateClose];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    return ![touch.view isDescendantOfView:floatingPanel];
}

#pragma mark - Animations

- (void)animatePanelEntrance {
    floatingPanel.alpha = 0;
    floatingPanel.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.9 options:0 animations:^{
        floatingPanel.alpha = 1;
        floatingPanel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)animateClose {
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseIn animations:^{
        floatingPanel.alpha = 0;
        floatingPanel.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL f) { [self closeSelf]; }];
}

- (void)closeSelf {
    [self.fpsTimer invalidate];
    self.fpsTimer = nil;
    [self saveUIState];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ModMenuDidClose" object:nil];
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - Position persistence

- (void)savePanelPosition:(CGPoint)origin {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setFloat:origin.x forKey:@"DuckdzPanelX"];
    [d setFloat:origin.y forKey:@"DuckdzPanelY"];
    [d synchronize];
}

- (CGPoint)loadPanelPosition {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    CGFloat x = [d floatForKey:@"DuckdzPanelX"];
    CGFloat y = [d floatForKey:@"DuckdzPanelY"];
    if (x == 0 && y == 0) return CGPointMake(40, 100);
    return CGPointMake(x, y);
}

#pragma mark - Screen capture

- (void)screenCaptureStatusChanged:(NSNotification *)n {
    if (StreamMode) {
        if (floatingPanel) UpdateStreamProtectionForView(floatingPanel);
        if (self.view)     UpdateStreamProtectionForView(self.view);
    }
}

#pragma mark - Feature Toggle Handlers (game logic unchanged)

- (void)toggleEnable:(UISwitch *)s          { Vars.Enable = s.on; }
- (void)toggleBox:(UISwitch *)s             { Vars.Box = s.on; }
- (void)toggleLines:(UISwitch *)s           { Vars.lines = s.on; }
- (void)toggleSkeleton:(UISwitch *)s        { if (s) Vars.Skeleton = s.on; }
- (void)toggleHealth:(UISwitch *)s          { if (s) Vars.Health = s.on; }
- (void)toggleDistance:(UISwitch *)s        { if (s) Vars.Distance = s.on; }
- (void)toggleName:(UISwitch *)s            { if (s) Vars.Name = s.on; }
- (void)toggleOutline:(UISwitch *)s         { if (s) Vars.Outline = s.on; }
- (void)toggleenemycount:(UISwitch *)s      { Vars.enemycount = s.on; }
- (void)toggleGlow:(UISwitch *)s            { Vars.Glow = s.on; }
- (void)toggleAimbot:(UISwitch *)s          { Vars.Aimbot = s.on; }
- (void)toggleAimsilent:(UISwitch *)s       { Vars.Aimsilent69 = s.on; }
- (void)toggleAimVisible:(UISwitch *)s      { Vars.Aimsilent69 = s.on; }
- (void)toggleIgnoreBot:(UISwitch *)s       { IgnoreBot = s.on; }
- (void)toggleIgnoreKnocked2:(UISwitch *)s  { IgnoreKnocked2 = s.on; }
- (void)toggleexa:(UISwitch *)s             { Vars.ShowEn = s.on; }
- (void)toggleAimKill:(UISwitch *)s         { Vars.playertakedamage2T = s.on; }
- (void)toggleRateOfFire:(UISwitch *)s      { Vars.rateoffire = s.on; }
- (void)sliderChanged:(UISlider *)s         { Vars.AimFov = s.value; UILabel *vl = objc_getAssociatedObject(s, "valueLabel"); if (vl) vl.text = [NSString stringWithFormat:@"%.0f", s.value]; }
- (void)fovThicknessChanged:(UISlider *)s   { AimbotFOVThickness = s.value; UILabel *vl = objc_getAssociatedObject(s, "valueLabel"); if (vl) vl.text = [NSString stringWithFormat:@"%.1f", s.value]; }
- (void)triggerChanged:(UISegmentedControl *)s { Vars.AimWhen = (int)s.selectedSegmentIndex; }
- (void)targetChanged:(UISegmentedControl *)s  { Vars.Target = (AimTarget)s.selectedSegmentIndex; }

- (void)toggleSpeedHack:(UISwitch *)s       { SpeedHack = s.on; }
- (void)toggleUpPlayer:(UISwitch *)s        { Vars.UpPlayer = s.on; }
- (void)toggleTelekill:(UISwitch *)s        { Vars.Telekill = s.on; [self saveSettingsToFile]; }
- (void)toggleTeleport8m:(UISwitch *)s      { Vars.Telekill = s.on; [self saveSettingsToFile]; }
- (void)toggleUndergroundKill2:(UISwitch *)s { Vars.UndergroundKill2 = s.on; }
- (void)toggleNinjaRun:(UISwitch *)s        { Vars.NinjaRun = s.on; }
- (void)toggleBloodIndia:(UISwitch *)s      {}
- (void)savePosSwitchChanged:(UISwitch *)sender { testGhost = sender.on; }
- (void)toggleFly:(UISwitch *)s             { Vars.fly = s.on; }
- (void)flyHeightChanged:(UISlider *)sl     { Vars.flyHeight = sl.value; UILabel *vl = objc_getAssociatedObject(sl, "valueLabel"); if (vl) vl.text = [NSString stringWithFormat:@"%.1f", sl.value]; }

- (void)toggleStreamMode:(UISwitch *)s {
    StreamMode = s.on;
    SetStreamMode(s.on);
    if (s.on) {
        if (floatingPanel) UpdateStreamProtectionForView(floatingPanel);
        if (self.view) UpdateStreamProtectionForView(self.view);
        reapplyStreamModeToAllESP();
    } else {
        if (floatingPanel) UpdateStreamProtectionForView(floatingPanel);
        if (self.view) UpdateStreamProtectionForView(self.view);
    }
}

- (void)toggleFastSwitch:(UISwitch *)s {
    FastSwitch = s.on;
    static bool wasswitch = false;
    if (FastSwitch) {
        void *addr[] = { (void *)getRealOffset(0x1051467BC) };
        void *func[] = { (void *)switchfast };
        Zexis(addr, func, 1);
        wasswitch = true;
    } else {
        if (wasswitch) { ZexisUnhook((void *)switchfast); wasswitch = false; }
    }
}

- (void)toggleStopLogs:(UISwitch *)s        { StopGarenaLogs = s.on; }

- (void)toggleResetGuest:(UISwitch *)s {
    Guest2 = s.on;
    static bool wasGuestHooked = false;
    if (Guest2) {
        void *addr[] = { (void *)getRealOffset(0x10126E688) };
        void *func[] = { (void *)Guest };
        Zexis(addr, func, 1);
        wasGuestHooked = true;
    } else {
        if (wasGuestHooked) { ZexisUnhook((void *)Guest); wasGuestHooked = false; }
    }
}

- (void)toggleFastMedkit:(UISwitch *)s {
    fmedkit = s.on;
    static bool wasfmHooked = false;
    if (fmedkit) {
        void *addr[] = { (void *)getRealOffset(0x1052C30C8) };
        void *func[] = { (void *)fastmedkit };
        Zexis(addr, func, 1);
        wasfmHooked = true;
    } else {
        if (wasfmHooked) { ZexisUnhook((void *)fastmedkit); wasfmHooked = false; }
    }
}

- (void)toggleForce120FPS:(UISwitch *)s {
    HighFPS = s.on;
    static bool wasFrame = false;
    if (HighFPS) {
        void *addr[] = { (void *)getRealOffset(0x1005FF44C) };
        void *func[] = { (void *)SetHighFPS };
        Zexis(addr, func, 1);
        wasFrame = true;
    } else {
        if (wasFrame) { ZexisUnhook((void *)SetHighFPS); wasFrame = false; }
    }
}

- (void)ninjaRunSlowTapped:(UIButton *)sender {
    Vars.NinjaRun_Slow = !Vars.NinjaRun_Slow;
    Vars.NinjaRun_Fast = NO;
    [self reloadContentForTab:MenuTabMSL animated:YES];
}

- (void)ninjaRunFastTapped:(UIButton *)sender {
    Vars.NinjaRun_Fast = !Vars.NinjaRun_Fast;
    Vars.NinjaRun_Slow = NO;
    [self reloadContentForTab:MenuTabMSL animated:YES];
}

- (void)updateUIButtonVisibility {
    if (self.isUpdatingUI) return;
    self.isUpdatingUI = YES;
    self.isUpdatingUI = NO;
}

- (void)protectAllFeatureButtons {}
- (void)unprotectAllFeatureButtons {}
- (void)showTabSelector {}
- (void)hideTabSelector {}

// Unused stubs kept for compatibility
- (void)tabOptionSelected:(UIButton *)sender {}
- (void)updateSidebarClipMask {}
- (void)updateContentClipMask {}
- (void)setupFloatingPanel {}
- (void)setupSidebar {}
- (void)setupHeaderBar {}
- (void)setupContentArea {}
- (CGFloat)addWarningLabel:(NSString *)t atY:(CGFloat)y width:(CGFloat)w padding:(CGFloat)p { return y; }
- (BOOL)isColor:(UIColor *)c1 similarTo:(UIColor *)c2 { return NO; }
- (void)updateAllColors {}
- (void)updateAllColorsWithFade {}
- (void)updateAllContentColors {}

@end
