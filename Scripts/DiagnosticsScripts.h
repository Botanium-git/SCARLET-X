#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface DiagnosticsScripts : NSObject
+ (void)installFlagsInto:(WKUserContentController *)contentController;
@end
