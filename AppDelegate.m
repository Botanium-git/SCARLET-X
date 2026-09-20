#import "AppDelegate.h"
#import "BrowserViewController.h"
#import "DiagnosticsStore.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.browserViewController = [[BrowserViewController alloc] init];
    self.window.rootViewController = self.browserViewController;
    [self.window makeKeyAndVisible];

    [[DiagnosticsStore shared] addEvent:@"Launch options dump"
                                  detail:[self diagnosticDescriptionForObject:launchOptions ?: @{}]
                                     url:nil];

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
    NSString *detail = [NSString stringWithFormat:@"URL: %@\nscheme: %@\nhost: %@\noptions: %@",
                        url.absoluteString ?: @"<nil>",
                        url.scheme ?: @"<nil>",
                        url.host ?: @"<nil>",
                        [self diagnosticDescriptionForObject:options ?: @{}]];
    [[DiagnosticsStore shared] addEvent:@"openURL raw dump" detail:detail url:url];
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
    NSString *detail = [NSString stringWithFormat:@"activityType: %@\nwebpageURL: %@\nuserInfo: %@",
                        userActivity.activityType ?: @"<nil>",
                        url.absoluteString ?: @"<nil>",
                        [self diagnosticDescriptionForObject:userActivity.userInfo ?: @{}]];
    [[DiagnosticsStore shared] addEvent:@"User activity dump" detail:detail url:url];
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && url) {
        [self handleIncomingURL:url source:@"continueUserActivity"];
        return YES;
    }
    return NO;
}

- (NSString *)diagnosticDescriptionForObject:(id)object {
    if (!object) return @"<nil>";
    @try {
        return [object descriptionWithLocale:nil indent:1] ?: [object description] ?: @"<no description>";
    } @catch (__unused NSException *exception) {
        return [object description] ?: @"<description failed>";
    }
}

- (void)handleIncomingURL:(NSURL *)url source:(NSString *)source {
    if (!url) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.browserViewController openExternalURL:url source:source];
    });
}

@end
