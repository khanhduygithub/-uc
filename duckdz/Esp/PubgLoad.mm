
#import "PubgLoad.h"
#import <UIKit/UIKit.h>
#include "oxorany/oxorany_include.h"
#import "JHPP.h"
#import "JHDragView.h"
// APIClient removed - direct initialization

#import <UIKit/UIKit.h>
#import "menuUIKIT/drawview.h"

@interface PubgLoad()
@end

@implementation PubgLoad

static PubgLoad *extraInfo;
static bool isUIKitMenuOpen = false;
UIWindow *mainWindow;

+ (void)load
{
    [super load];
    
    // Direct initialization without API check
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        mainWindow = [UIApplication sharedApplication].keyWindow;
        
        if (!mainWindow) {
            NSLog(@"[Fluck] Warning: keyWindow is nil, retrying...");
            // Retry after 2 seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                mainWindow = [UIApplication sharedApplication].keyWindow;
                [PubgLoad initializeMenu];
            });
        } else {
            [PubgLoad initializeMenu];
        }
    });
}

+ (void)initializeMenu
{
    extraInfo = [PubgLoad new];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(menuDidClose) 
                                                 name:@"ModMenuDidClose" 
                                               object:nil];
    [extraInfo initUIKitGesture];
    
    NSLog(@"[Fluck] ✅ Menu initialized successfully!");
}

#pragma mark - UIKit Mod Menu Gesture

- (void)initUIKitGesture {
    UIViewController *currentVC = [JHPP currentViewController];
    if (!currentVC || !currentVC.view) {
        NSLog(@"[Fluck] Warning: Cannot add gestures - no view controller");
        return;
    }
    
    // Open menu: 3-finger double tap
    UITapGestureRecognizer *openTap = [[UITapGestureRecognizer alloc] init];
    openTap.numberOfTapsRequired = 2;
    openTap.numberOfTouchesRequired = 3;
    [openTap addTarget:self action:@selector(openUIKitMenu)];
    [currentVC.view addGestureRecognizer:openTap];

    // Close menu: 2-finger single tap
    UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] init];
    closeTap.numberOfTapsRequired = 1;
    closeTap.numberOfTouchesRequired = 2;
    [closeTap addTarget:self action:@selector(closeUIKitMenu)];
    [currentVC.view addGestureRecognizer:closeTap];
    
    NSLog(@"[Fluck] Gestures added: 3-finger 2-tap = OPEN | 2-finger tap = CLOSE");
}

- (void)openUIKitMenu {
    if (isUIKitMenuOpen) {
        NSLog(@"[Fluck] Menu already open");
        return;
    }

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        NSLog(@"[Fluck] Cannot open menu - no keyWindow");
        return;
    }

    UIViewController *rootVC = window.rootViewController;
    if (!rootVC) {
        NSLog(@"[Fluck] Cannot open menu - no root VC");
        return;
    }

    ModMenuViewController *menuVC = [[ModMenuViewController alloc] init];
    menuVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [rootVC presentViewController:menuVC animated:NO completion:^{
        NSLog(@"[Fluck] ✅ Menu opened");
    }];

    isUIKitMenuOpen = true;
}

+ (void)menuDidClose {
    isUIKitMenuOpen = false;
    NSLog(@"[Fluck] Menu closed");
}

- (void)closeUIKitMenu {
    if (!isUIKitMenuOpen) {
        NSLog(@"[Fluck] Menu not open");
        return;
    }

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    
    UIViewController *vc = window.rootViewController.presentedViewController;
    if ([vc isKindOfClass:[ModMenuViewController class]]) {
        [vc dismissViewControllerAnimated:NO completion:^{
            NSLog(@"[Fluck] ✅ Menu dismissed");
        }];
        isUIKitMenuOpen = false;
    }
}

@end
