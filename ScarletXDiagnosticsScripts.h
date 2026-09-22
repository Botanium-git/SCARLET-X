#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface ScarletXDiagnosticsScripts : NSObject
+ (void)installFlagsInto:(WKUserContentController *)contentController;
@end
