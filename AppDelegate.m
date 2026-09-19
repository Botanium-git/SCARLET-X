#import "AppDelegate.h"
#import "BrowserViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.browserViewController = [[BrowserViewController alloc] init];
    self.window.rootViewController = self.browserViewController;
    [self.window makeKeyAndVisible];

    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    if (url) {
        [self handleIncomingURL:url source:@"launchOptions"];
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

- (void)handleIncomingURL:(NSURL *)url source:(NSString *)source {
    if (!url) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.browserViewController openExternalURL:url source:source];
    });
}

@end
