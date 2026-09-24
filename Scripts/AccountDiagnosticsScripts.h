#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface AccountDiagnosticsScripts : NSObject
+ (void)installInto:(WKUserContentController *)contentController;
@end
