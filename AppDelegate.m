#import "AppDelegate.h"
#import "BrowserViewController.h"
#import "DiagnosticsStore.h"

@implementation AppDelegate {
    NSString *_lastIncomingURL;
    NSTimeInterval _lastIncomingURLTime;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.browserViewController = [[BrowserViewController alloc] init];
    self.window.rootViewController = self.browserViewController;
    [self.window makeKeyAndVisible];

    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    if (url) {
        [self handleIncomingURL:url source:@"launchOptions"];
    }

    NSDictionary *activityDictionary = launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey];
    for (NSUserActivity *activity in activityDictionary.allValues) {
        if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && activity.webpageURL) {
            [self handleIncomingURL:activity.webpageURL source:@"launchOptions userActivity"];
            break;
        }
    }

    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    [self handleIncomingURL:url source:@"openURL:options:"];
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    [self handleIncomingURL:url source:@"handleOpenURL:"];
    return YES;
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable restorableObjects))restorationHandler {
    NSURL *url = userActivity.webpageURL;
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && url) {
        [self handleIncomingURL:url source:@"continueUserActivity"];
        return YES;
    }
    return NO;
}

- (void)handleIncomingURL:(NSURL *)url source:(NSString *)source {
    if (!url) return;
    NSString *absolute = url.absoluteString ?: @"";
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (_lastIncomingURL && [_lastIncomingURL isEqualToString:absolute] && (now - _lastIncomingURLTime) < 1.0) return;
    _lastIncomingURL = [absolute copy];
    _lastIncomingURLTime = now;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.browserViewController openExternalURL:url source:source];
    });
}

@end
