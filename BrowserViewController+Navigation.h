#import "BrowserViewController.h"

@interface BrowserViewController (Navigation)
- (BOOL)isWebURL:(NSURL *)url;
- (NSURL *)unwrapScarletURL:(NSURL *)url;
- (void)loadURL:(NSURL *)url reason:(NSString *)reason;
- (void)goHome;
@end
