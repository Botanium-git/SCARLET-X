#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface DisplayScripts : NSObject
+ (void)installSettingsScriptInto:(WKUserContentController *)contentController;
+ (void)installDisplayCustomizationInto:(WKUserContentController *)contentController;
@end
