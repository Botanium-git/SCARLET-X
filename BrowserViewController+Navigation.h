#import "BrowserViewController.h"

@interface BrowserViewController (Navigation)
- (BOOL)isWebURL:(NSURL *)url;
- (NSURL *)unwrapScarletURL:(NSURL *)url;
- (void)openExternalURL:(NSURL *)url source:(NSString *)source;
- (void)loadURL:(NSURL *)url reason:(NSString *)reason;
- (void)goHome;
@end
