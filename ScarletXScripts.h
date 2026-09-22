#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface ScarletXScripts : NSObject
+ (void)installSettingsScriptInto:(WKUserContentController *)contentController;
+ (void)installDisplayCustomizationInto:(WKUserContentController *)contentController;
@end
