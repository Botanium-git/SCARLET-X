#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "../Diagnostics/DiagnosticsStore.h"
#import "../Browser/BrowserViewController.h"

@implementation BrowserViewController (ClosedDOMStructureProbe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(webView:didFinishNavigation:));
        Method probe = class_getInstanceMethod(self, @selector(sx_probe_webView:didFinishNavigation:));
        if (original && probe) method_exchangeImplementations(original, probe);
    });
}

- (void)sx_probe_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self sx_probe_webView:webView didFinishNavigation:navigation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *script = @"(function(){function c(s){try{return document.querySelectorAll(s).length}catch(e){return -1}}var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');return {profileButton:!!p,profileImage:!!(p&&p.querySelector('img')),profileAriaLabel:!!(p&&p.hasAttribute('aria-label')),profileHref:!!(p&&p.hasAttribute('href')),dialogs:c('[role=\\\"dialog\\\"]'),menus:c('[role=\\\"menu\\\"]'),accountSwitcher:c('[data-testid=\\\"SideNav_AccountSwitcher_Button\\\"]'),accountSwitchButtons:c('button[aria-label$=\\\"に切り替える\\\"]'),navLinks:c('nav a[href]'),allLinks:c('a[href]'),images:c('img')};})()";
        [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if (error) {
                [[DiagnosticsStore shared] addEvent:@"Closed DOM structure" detail:[NSString stringWithFormat:@"probe failed: %@", error.localizedDescription ?: @"unknown"] url:webView.URL];
                return;
            }
            NSData *data = [NSJSONSerialization dataWithJSONObject:[result isKindOfClass:NSDictionary.class] ? result : @{} options:0 error:nil];
            NSString *detail = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"{}";
            [[DiagnosticsStore shared] addEvent:@"Closed DOM structure" detail:detail url:webView.URL];
        }];
    });
}

@end
