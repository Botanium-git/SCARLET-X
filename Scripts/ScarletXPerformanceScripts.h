#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface ScarletXPerformanceScripts : NSObject
+ (void)installInto:(WKUserContentController *)contentController;
@end
