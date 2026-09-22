#import <UIKit/UIKit.h>

@class BrowserViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) BrowserViewController *browserViewController;

- (void)handleIncomingURL:(NSURL *)url source:(NSString *)source;

@end
