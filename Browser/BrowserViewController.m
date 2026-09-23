#import "BrowserViewController.h"
#import "../UI/SettingsViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import "../Scripts/DisplayScripts.h"
#import "../Scripts/DiagnosticsScripts.h"
#import "../Scripts/RuntimeScripts.h"
#import "BrowserViewController+Navigation.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NativeDrawerViewControllerDelegate>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@property(nonatomic,assign) CFTimeInterval navigationStartTime;
@property(nonatomic,assign) CFTimeInterval requestStartTime;
@property(nonatomic,assign) NSInteger navigationSession;
@property(nonatomic,assign) BOOL requestPending;
@property(nonatomic,copy) NSString *navigationReason;
@property(nonatomic,strong) NativeDrawerViewController *nativeDrawer;
@end

@implementation BrowserViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [[DiagnosticsStore shared] addEvent:@"App launched" detail:@"Browser view created" url:nil];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *contentController = [WKUserContentController new];
    [contentController addScriptMessageHandler:self name:@"scarletx"];
    [DisplayScripts installSettingsScriptInto:contentController];
    [DisplayScripts installDisplayCustomizationInto:contentController];
    [DiagnosticsScripts installFlagsInto:contentController];
    [RuntimeScripts installInto:contentController];

    NSString *nativeDrawerBridge = @"(function(){if(window.__scarletXNativeDrawerInstalled)return;window.__scarletXNativeDrawerInstalled=true;document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p)return;e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer'});}catch(_){}},true);})();";
    [contentController addUserScript:[[WKUserScript alloc] initWithSource:nativeDrawerBridge injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];

    config.userContentController = contentController;
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1";
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.webView evaluateJavaScript:@"JSON.stringify({userAgent:navigator.userAgent,vendor:navigator.vendor,platform:navigator.platform})" completionHandler:^(id result, NSError *error) {
        if (error) { [[DiagnosticsStore shared] addError:@"Browser identity probe failed" error:error url:nil]; return; }
        [[DiagnosticsStore shared] addEvent:@"Browser identity" detail:[result description] ?: @"" url:nil];
    }];

    [self.view addSubview:self.webView];
    [NSLayoutConstraint activateConstraints:@[
      [self.webView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
      [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
      [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    if (self.pendingURL) { NSURL *u=self.pendingURL; self.pendingURL=nil; [self loadURL:u reason:@"pending"]; }
    else [self goHome];
}
- (void)openExternalURL:(NSURL *)url source:(NSString *)source {
    if(!url)return; NSURL *target=[self unwrapScarletURL:url];
    [[DiagnosticsStore shared] addEvent:@"Received external URL" detail:source ?: @"" url:target];
    dispatch_async(dispatch_get_main_queue(), ^{ if(!self.isViewLoaded)self.pendingURL=target; else [self loadURL:target reason:source]; });
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx"]) return;
    if ([message.body isEqual:@"settings"]) { [self openSettings]; return; }
    if ([message.body isKindOfClass:NSDictionary.class] && [message.body[@"type"] isEqual:@"native-drawer"]) { [self openNativeDrawer]; return; }
    if ([message.body isKindOfClass:NSDictionary.class] && [message.body[@"type"] isEqual:@"performance"]) {
        NSDictionary *body = message.body;
        CFTimeInterval elapsed = self.navigationStartTime > 0 ? (CACurrentMediaTime() - self.navigationStartTime) * 1000.0 : 0;
        CFTimeInterval requestElapsed = self.requestStartTime > 0 ? (CACurrentMediaTime() - self.requestStartTime) * 1000.0 : 0;
        NSDictionary *extra = [body[@"extra"] isKindOfClass:NSDictionary.class] ? body[@"extra"] : @{};
        NSData *extraData = [NSJSONSerialization dataWithJSONObject:extra options:0 error:nil];
        NSString *extraJSON = extraData ? [[NSString alloc] initWithData:extraData encoding:NSUTF8StringEncoding] : @"{}";
        NSString *detail = [NSString stringWithFormat:@"Stage: %@\nSession: %ld\nNavigation elapsed: %.0f ms\nRequest elapsed: %.0f ms\nPage performance.now: %@ ms\nReason: %@\nExtra: %@", body[@"stage"] ?: @"", (long)self.navigationSession, elapsed, requestElapsed, body[@"now"] ?: @0, self.navigationReason ?: @"", extraJSON ?: @"{}"];
        [[DiagnosticsStore shared] addEvent:@"Page performance" detail:detail url:self.webView.URL];
    }
}
- (void)openNativeDrawer {
    if (self.nativeDrawer.parentViewController) return;
    self.nativeDrawer = [NativeDrawerViewController new];
    self.nativeDrawer.delegate = self;
    [self.nativeDrawer presentInParent:self];
}
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    NSURL *url = [NSURL URLWithString:[@"https://x.com" stringByAppendingString:path]];
    [self loadURL:url reason:@"Native drawer"];
}
- (void)nativeDrawerDidSelectScarletSettings:(NativeDrawerViewController *)drawer { [self openSettings]; }
- (void)openSettings {
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[SettingsViewController new]];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation { self.navigationStartTime = CACurrentMediaTime(); self.navigationSession += 1; if (!self.requestPending) { self.requestStartTime = 0; self.navigationReason = @"Web"; } self.requestPending = NO; NSString *detail=[NSString stringWithFormat:@"Session %ld | %@", (long)self.navigationSession, self.navigationReason ?: @""]; [[DiagnosticsStore shared] addEvent:@"Navigation started" detail:detail url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { CFTimeInterval elapsed = self.navigationStartTime > 0 ? (CACurrentMediaTime() - self.navigationStartTime) * 1000.0 : 0; CFTimeInterval requestElapsed = self.requestStartTime > 0 ? (CACurrentMediaTime() - self.requestStartTime) * 1000.0 : 0; NSString *detail=[NSString stringWithFormat:@"Session %ld | Navigation %.0f ms | Request %.0f ms | %@", (long)self.navigationSession, elapsed, requestElapsed, self.navigationReason ?: @""]; [[DiagnosticsStore shared] addEvent:@"Navigation finished" detail:detail url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [[DiagnosticsStore shared] addError:@"Provisional navigation failed" error:error url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) { [[DiagnosticsStore shared] addEvent:@"Navigation cancelled" detail:@"Superseded or cancelled navigation (-999)" url:webView.URL]; return; } [[DiagnosticsStore shared] addError:@"Navigation failed" error:error url:webView.URL]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { [[DiagnosticsStore shared] addEvent:@"Web content process terminated" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)a decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url=a.request.URL; NSString *s=url.scheme.lowercaseString;
    if([self isWebURL:url]||[s isEqual:@"about"]||[s isEqual:@"blob"]||[s isEqual:@"data"]) { decisionHandler(WKNavigationActionPolicyAllow); return; }
    if ([s isEqual:@"x-safari-https"]) { [[DiagnosticsStore shared] addEvent:@"Intercepted x-safari-https" detail:@"Navigation cancelled to prevent redirect loop" url:url]; decisionHandler(WKNavigationActionPolicyCancel); return; }
    [[DiagnosticsStore shared] addEvent:@"Blocked scheme" detail:s ?: @"" url:url]; decisionHandler(WKNavigationActionPolicyCancel);
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)a windowFeatures:(WKWindowFeatures *)windowFeatures { if(a.targetFrame==nil&&a.request.URL)[webView loadRequest:a.request]; return nil; }
@end
