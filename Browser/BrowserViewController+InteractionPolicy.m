#import "BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@implementation BrowserViewController (InteractionPolicy)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_interactionPolicy_viewDidLoad));
        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });
}

- (void)sx_interactionPolicy_viewDidLoad {
    [self sx_interactionPolicy_viewDidLoad];

    WKWebView *webView = nil;
    @try {
        webView = [self valueForKey:@"webView"];
    } @catch (__unused NSException *exception) {
        webView = nil;
    }

    if (webView) {
        webView.allowsLinkPreview = NO;
    }
}

- (void)webView:(WKWebView *)webView
contextMenuConfigurationForElement:(WKContextMenuElementInfo *)elementInfo
completionHandler:(void (^)(UIContextMenuConfiguration * _Nullable configuration))completionHandler {
    completionHandler(nil);
}

@end
