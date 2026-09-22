#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface RuntimeScripts : NSObject
+ (void)installInto:(WKUserContentController *)contentController;
@end
