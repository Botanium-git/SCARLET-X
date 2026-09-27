#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "../Browser/BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"

@interface BrowserViewController (QuickLogExportOriginal)
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;
@end

@implementation BrowserViewController (QuickLogExport)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method navOriginal = class_getInstanceMethod(self, @selector(webView:didFinishNavigation:));
        Method navReplacement = class_getInstanceMethod(self, @selector(sx_quickLog_webView:didFinishNavigation:));
        if (navOriginal && navReplacement) method_exchangeImplementations(navOriginal, navReplacement);

        Method messageOriginal = class_getInstanceMethod(self, @selector(userContentController:didReceiveScriptMessage:));
        Method messageReplacement = class_getInstanceMethod(self, @selector(sx_quickLog_userContentController:didReceiveScriptMessage:));
        if (messageOriginal && messageReplacement) method_exchangeImplementations(messageOriginal, messageReplacement);
    });
}

- (void)sx_installQuickLogButton {
    // Intentionally empty. Quick log export now lives on a long press of the X profile icon.
}

- (void)sx_quickLog_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self sx_quickLog_webView:webView didFinishNavigation:navigation];

    NSString *script = @"(function(){"
        "if(window.__scarletXLongPressLogInstalled)return;"
        "window.__scarletXLongPressLogInstalled=true;"
        "var timer=null,target=null,fired=false;"
        "function profileFromEvent(e){var n=e&&e.target;return n&&n.closest?n.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;}"
        "function clear(){if(timer){clearTimeout(timer);timer=null;}target=null;}"
        "document.addEventListener('touchstart',function(e){"
            "var p=profileFromEvent(e);if(!p)return;clear();target=p;fired=false;"
            "timer=setTimeout(function(){timer=null;if(!target)return;fired=true;"
                "try{window.webkit.messageHandlers.scarletx.postMessage({type:'quick-log-export'});}catch(_){}"
            "},600);"
        "},{capture:true,passive:false});"
        "document.addEventListener('touchmove',function(e){if(target&&!fired)clear();},{capture:true,passive:false});"
        "document.addEventListener('touchcancel',function(){clear();fired=false;},{capture:true,passive:false});"
        "document.addEventListener('touchend',function(e){"
            "if(!target)return;var consumed=fired;clear();"
            "if(consumed){e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();setTimeout(function(){fired=false;},0);}"
        "},{capture:true,passive:false});"
        "document.addEventListener('contextmenu',function(e){if(profileFromEvent(e)&&fired){e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();}},true);"
    "})();";
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            [[DiagnosticsStore shared] addError:@"Quick log long-press install failed" error:error url:webView.URL];
        }
    }];
}

- (void)sx_quickLog_userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"scarletx"] && [message.body isKindOfClass:NSDictionary.class]) {
        NSString *type = [message.body[@"type"] isKindOfClass:NSString.class] ? message.body[@"type"] : @"";
        if ([type isEqualToString:@"quick-log-export"]) {
            [[DiagnosticsStore shared] addEvent:@"Quick log export" detail:@"Profile icon long press" url:nil];
            [self sx_exportDiagnostics:nil];
            return;
        }
    }
    [self sx_quickLog_userContentController:userContentController didReceiveScriptMessage:message];
}

- (void)sx_shareDiagnostics:(UIView *)sender {
    NSArray *entries = DiagnosticsStore.shared.diagnosticEntries ?: @[];
    NSDictionary *payload = @{
        @"format": @"ScarletXLog",
        @"version": @2,
        @"type": @"diagnostics",
        @"exportedAt": @([[NSDate date] timeIntervalSince1970]),
        @"appVersion": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        @"build": NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"",
        @"entries": entries
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) return;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *name = [NSString stringWithFormat:@"ScarletX_DiagnosticLog_%@.json", [formatter stringFromDate:[NSDate date]]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    if (![data writeToURL:url atomically:YES]) return;
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    UIView *anchor = sender ?: self.view;
    share.popoverPresentationController.sourceView = anchor;
    share.popoverPresentationController.sourceRect = sender ? sender.bounds : CGRectMake(CGRectGetMidX(anchor.bounds), 44.0, 1.0, 1.0);
    [self presentViewController:share animated:YES completion:nil];
}

- (void)sx_exportDiagnostics:(UIView *)sender {
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *e) {}
    if (!webView) { [self sx_shareDiagnostics:sender]; return; }

    NSString *script = @"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var img=p&&p.querySelector('img');var dialogs=document.querySelectorAll('[role=dialog],[role=menu]');var buttons=document.querySelectorAll('button[aria-label$=\\\"に切り替える\\\"]');return {probe:'closed-dom',profileExists:!!p,profileExpanded:p?(p.getAttribute('aria-expanded')||''):'',profileLabel:p?(p.getAttribute('aria-label')||''):'',profileImage:img?(img.currentSrc||img.src||''):'',dialogCount:dialogs.length,switchButtonCount:buttons.length,switchLabels:Array.from(buttons).map(function(b){return b.getAttribute('aria-label')||'';})};})()";
    __weak typeof(self) weakSelf = self;
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        if (error) {
            [[DiagnosticsStore shared] addError:@"Closed DOM snapshot failed" error:error url:webView.URL];
        } else {
            NSData *json = [NSJSONSerialization dataWithJSONObject:[result isKindOfClass:NSDictionary.class] ? result : @{} options:NSJSONWritingPrettyPrinted error:nil];
            NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";
            [[DiagnosticsStore shared] addEvent:@"Closed DOM snapshot" detail:detail url:webView.URL];
        }
        [self sx_shareDiagnostics:sender];
    }];
}

@end
