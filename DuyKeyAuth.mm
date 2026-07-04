// DuyKeyAuth.mm
// Client-side license check. Talks to api/connect.php on your web panel.
//
// Uses obf.h / obf.mm for string obfuscation: literals below (URLs params,
// UserDefaults key, alert titles/messages) are stored encoded in the
// binary and only decoded at the point of use, at runtime. Ciphertext
// changes every time you rebuild (seed mixes __TIME__/__DATE__), so you
// don't need to touch this file to get a fresh obfuscated build.
//
// kBaseAPIURL / kPackageToken stay in HeaderAPI.h, in plaintext, on
// purpose — that's the file end users are meant to edit per-project.
//
// NOTE on security model: this class only decides what the *app* does
// locally (show a key prompt, proceed, or exit). The actual enforcement —
// is this key valid, active, not expired, under its device limit — always
// happens server-side in connect.php. Obfuscating this file raises the
// cost of static inspection; it doesn't make client-side checks
// authoritative. Don't rely on this file alone for anything that matters.

#import "HeaderAPI.h"
#import "obf.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *_xqDefaultsKey(void) {
    return XQNS("saved_license_key");
}

@interface Zk9QxAuth : NSObject

@property (nonatomic, copy) NSString *vQt3Link;   // was: contactLink
@property (nonatomic, assign) BOOL mZk8Flag;       // was: isMaintenance

+ (instancetype)q7ZmA;   // was: sharedInstance
- (void)a1Run;           // was: startProcess

@end

@implementation Zk9QxAuth

#pragma mark - Lifecycle

+ (instancetype)q7ZmA {
    static Zk9QxAuth *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Zk9QxAuth alloc] init];
        sharedInstance.vQt3Link = @"";
    });
    return sharedInstance;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        [[Zk9QxAuth q7ZmA] a1Run];
    });
}

#pragma mark - Networking helpers

// was: urlForAction:extraParams:
- (nullable NSURL *)u9x:(NSString *)action y3:(NSDictionary<NSString *, NSString *> *)extra {
    NSURLComponents *comps = [NSURLComponents componentsWithString:kBaseAPIURL];
    if (!comps) return nil;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [items addObject:[NSURLQueryItem queryItemWithName:XQNS("action") value:action]];
    [items addObject:[NSURLQueryItem queryItemWithName:XQNS("token") value:kPackageToken]];
    for (NSString *k in extra) {
        [items addObject:[NSURLQueryItem queryItemWithName:k value:extra[k]]];
    }
    comps.queryItems = items;
    return comps.URL;
}

// was: getJSONFromURL:completion:
- (void)g7q:(NSURL *)url c2:(void (^)(NSDictionary * _Nullable json, NSError * _Nullable error))completion {
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                          timeoutInterval:15.0];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    completion(nil, error);
                    return;
                }
                if (!data) {
                    completion(nil, [NSError errorWithDomain:XQNS("DuyKeyAuth") code:-1
                                                      userInfo:@{NSLocalizedDescriptionKey: XQNS("Không có dữ liệu trả về.")}]);
                    return;
                }
                NSError *jsonError = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
                    completion(nil, jsonError ?: [NSError errorWithDomain:XQNS("DuyKeyAuth") code:-2
                                                                   userInfo:@{NSLocalizedDescriptionKey: XQNS("Dữ liệu server không hợp lệ.")}]);
                    return;
                }
                completion((NSDictionary *)json, nil);
            });
        }];
    [task resume];
}

#pragma mark - Step 1: init

// was: startProcess
- (void)a1Run {
    NSURL *url = [self u9x:XQNS("init") y3:@{}];
    if (!url) {
        [self f0e:XQNS("Cấu hình kBaseAPIURL không hợp lệ.")];
        return;
    }

    [self g7q:url c2:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error || !json) {
            [self f0e:XQNS("Không thể kết nối đến server.")];
            return;
        }
        if ([json[XQNS("force_exit")] boolValue]) {
            [self f0e:json[XQNS("message")] ?: XQNS("Token package không tồn tại.")];
            return;
        }
        if (![json[XQNS("status")] boolValue]) {
            [self f0e:json[XQNS("message")] ?: XQNS("Lỗi không xác định.")];
            return;
        }

        if ([json[XQNS("contact")] isKindOfClass:[NSString class]]) {
            self.vQt3Link = json[XQNS("contact")];
        }
        self.mZk8Flag = [json[XQNS("maintenance")] boolValue];

        [self h4s];
    }];
}

// was: handleInitSuccess
- (void)h4s {
    if (self.mZk8Flag) {
        [self s5m];
        return;
    }

    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:_xqDefaultsKey()];
    if (savedKey.length > 0) {
        [self c8k:savedKey a9:YES];
    } else {
        [self s6k];
    }
}

#pragma mark - Step 2: key entry & verification

// was: showMaintenanceAlert
- (void)s5m {
    UIViewController *rootVC = [self t1v];
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:XQNS("Bảo Trì")
                                                                     message:XQNS("Hệ thống đang bảo trì.")
                                                              preferredStyle:UIAlertControllerStyleAlert];
    if (self.vQt3Link.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:XQNS("Liên hệ") style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.vQt3Link] options:@{} completionHandler:nil];
            exit(0);
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:XQNS("Thoát") style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) { exit(0); }]];
    }
    [rootVC presentViewController:alert animated:YES completion:nil];
}

// was: showKeyAlert
- (void)s6k {
    UIViewController *rootVC = [self t1v];
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:XQNS("Nhập Key")
                                                                     message:XQNS("Vui lòng nhập key để kích hoạt.")
                                                              preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = XQNS("License Key");
        textField.textAlignment = NSTextAlignmentCenter;
        textField.keyboardAppearance = UIKeyboardAppearanceDark;
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.returnKeyType = UIReturnKeyDone;
    }];

    __weak __typeof(self) weakSelf = self;

    if (self.vQt3Link.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:XQNS("Contact") style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:weakSelf.vQt3Link] options:@{} completionHandler:nil];
            [weakSelf s6k];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:XQNS("Login") style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [weakSelf c8k:trimmed a9:NO];
        } else {
            [weakSelf s6k];
        }
    }]];

    [rootVC presentViewController:alert animated:YES completion:nil];
}

// was: checkKey:isAuto:
- (void)c8k:(NSString *)key a9:(BOOL)isAuto {
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"";
    NSURL *url = [self u9x:XQNS("check") y3:@{XQNS("key"): key, XQNS("uuid"): uuid}];
    if (!url) {
        [self s7a:XQNS("Lỗi") m8:XQNS("Không thể tạo request.") r9:!isAuto];
        return;
    }

    [self g7q:url c2:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error || !json) {
            [self s7a:XQNS("Lỗi kết nối") m8:error.localizedDescription ?: XQNS("Không thể kết nối đến server.") r9:NO];
            return;
        }

        if ([json[XQNS("force_exit")] boolValue]) {
            [self f0e:json[XQNS("message")] ?: XQNS("Token package lỗi.")];
            return;
        }
        if ([json[XQNS("contact")] isKindOfClass:[NSString class]]) {
            self.vQt3Link = json[XQNS("contact")];
        }

        if (![json[XQNS("status")] boolValue]) {
            [self h1v:key m2:json[XQNS("message")] ?: XQNS("Key không hợp lệ.") a3:isAuto];
            return;
        }

        NSInteger daysLeft = [json[XQNS("days_left")] integerValue];
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:_xqDefaultsKey()];
        [[NSUserDefaults standardUserDefaults] synchronize];

        NSString *info = [NSString stringWithFormat:@"%@: %@ (%ld %@)",
                           XQNS("Hạn dùng"), json[XQNS("expiry")] ?: @"-", (long)daysLeft, XQNS("ngày")];
        [self s7a:XQNS("Thành công") m8:info r9:NO];
    }];
}

// was: handleInvalidKey:message:isAuto:
- (void)h1v:(NSString *)key m2:(nullable NSString *)msg a3:(BOOL)isAuto {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:_xqDefaultsKey()];

    if (isAuto) {
        [self s6k];
    } else {
        [self s7a:XQNS("Lỗi Key") m8:msg ?: XQNS("Key không hợp lệ.") r9:YES];
    }
}

#pragma mark - Alerts & exit

// was: showAlert:message:retry:
- (void)s7a:(NSString *)title m8:(nullable NSString *)message r9:(BOOL)retry {
    UIViewController *rootVC = [self t1v];
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
    __weak __typeof(self) weakSelf = self;

    if (self.vQt3Link.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:XQNS("Liên hệ") style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:weakSelf.vQt3Link] options:@{} completionHandler:nil];
            if (retry) [weakSelf s6k];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:XQNS("OK") style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *action) {
        if (retry) [weakSelf s6k];
    }]];

    [rootVC presentViewController:alert animated:YES completion:nil];
}

// was: forceExitApp:
- (void)f0e:(NSString *)reason {
    UIViewController *rootVC = [self t1v];
    if (!rootVC) {
        exit(0);
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:XQNS("Lỗi Hệ Thống")
                                                                     message:reason
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:XQNS("Thoát") style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *action) { exit(0); }]];
    [rootVC presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Utility

// was: topViewController
- (nullable UIViewController *)t1v {
    UIWindow *keyWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
            if (keyWindow) break;
        }
    }
    if (!keyWindow) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    UIViewController *vc = keyWindow.rootViewController;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

@end

NS_ASSUME_NONNULL_END
