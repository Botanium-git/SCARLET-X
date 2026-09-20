#import "BrowserViewController.h"
#import "SettingsViewController.h"
#import "DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@end

@implementation BrowserViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [[DiagnosticsStore shared] addEvent:@"App launched" detail:@"Browser view created" url:nil];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *contentController = [WKUserContentController new];
    [contentController addScriptMessageHandler:self name:@"scarletx"];
    NSString *settingsScript = @"(function(){"
        "if(window.__scarletXSettingsInstalled)return;"
        "window.__scarletXSettingsInstalled=true;"
        "function rect(e){var r=e.getBoundingClientRect();return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)};}"
        "function desc(e,i){if(!e)return null;return {level:i,tag:e.tagName,role:e.getAttribute&&e.getAttribute('role'),href:e.getAttribute&&e.getAttribute('href'),id:e.id||'',className:(typeof e.className==='string'?e.className:''),rect:rect(e),childCount:e.children?e.children.length:0,text:(e.innerText||'').trim().slice(0,120)};}"
        "function send(anchor){"
          "if(window.__scarletXDomDiagnosticSent)return;"
          "window.__scarletXDomDiagnosticSent=true;"
          "var chain=[],e=anchor;"
          "for(var i=0;e&&i<7;i++,e=e.parentElement)chain.push(desc(e,i));"
          "var payload={type:'dom-diagnostic',viewport:{w:window.innerWidth,h:window.innerHeight},anchor:desc(anchor,-1),ancestors:chain};"
          "window.webkit.messageHandlers.scarletx.postMessage(payload);"
        "}"
        "function inspect(){"
          "var candidates=[].slice.call(document.querySelectorAll('a[href=\"/settings\"],a[href=\"/settings/account\"]'));"
          "var anchor=candidates.find(function(a){return (a.innerText||'').indexOf('設定とプライバシー')!==-1;})||candidates[0];"
          "if(!anchor)return;"
          "send(anchor);"
        "}"
        "new MutationObserver(inspect).observe(document.documentElement,{childList:true,subtree:true});"
        "inspect();"
      "})();";
    WKUserScript *script = [[WKUserScript alloc] initWithSource:settingsScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [contentController addUserScript:script];
    config.userContentController = contentController;
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    // A/B test: identify as Chrome on iOS while keeping the WebKit engine and
    // all other ScarletX settings unchanged.
    self.webView.customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1";
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;

    // Record the actual browser identity exposed by this WKWebView before changing it.
    // This gives us a clean baseline to compare with Chrome/Safari on the same device.
    [self.webView evaluateJavaScript:@"JSON.stringify({userAgent:navigator.userAgent,vendor:navigator.vendor,platform:navigator.platform})"
                   completionHandler:^(id result, NSError *error) {
        if (error) {
            [[DiagnosticsStore shared] addError:@"Browser identity probe failed" error:error url:nil];
            return;
        }
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
- (BOOL)isWebURL:(NSURL *)url { NSString *s=url.scheme.lowercaseString; return [s isEqual:@"https"]||[s isEqual:@"http"]; }
- (NSURL *)unwrapScarletURL:(NSURL *)url {
    if (![[url.scheme lowercaseString] isEqual:@"scarletx"]) return url;
    NSURLComponents *c=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *i in c.queryItems) if ([i.name isEqual:@"url"]&&i.value.length) { NSURL *u=[NSURL URLWithString:i.value]; if(u)return u; }
    return [NSURL URLWithString:@"https://x.com/"];
}
- (void)openExternalURL:(NSURL *)url source:(NSString *)source {
    if(!url)return; NSURL *target=[self unwrapScarletURL:url];
    [[DiagnosticsStore shared] addEvent:@"Received external URL" detail:source ?: @"" url:target];
    dispatch_async(dispatch_get_main_queue(), ^{ if(!self.isViewLoaded)self.pendingURL=target; else [self loadURL:target reason:source]; });
}
- (void)loadURL:(NSURL *)url reason:(NSString *)reason {
    if(![self isWebURL:url]) { [[DiagnosticsStore shared] addEvent:@"Unsupported URL" detail:url.scheme ?: @"" url:url]; return; }
    [[DiagnosticsStore shared] addEvent:@"Loading URL" detail:reason ?: @"" url:url];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}
- (void)goHome { [self loadURL:[NSURL URLWithString:@"https://x.com/home"] reason:@"Home"]; }
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx"]) return;
    if ([message.body isEqual:@"settings"]) {
        [self openSettings];
        return;
    }
    if ([message.body isKindOfClass:NSDictionary.class] && [message.body[@"type"] isEqual:@"dom-diagnostic"]) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:message.body options:NSJSONWritingPrettyPrinted error:&error];
        NSString *detail = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : [message.body description];
        if (error) detail = [NSString stringWithFormat:@"Serialization error: %@\n%@", error.localizedDescription, [message.body description]];
        [[DiagnosticsStore shared] addEvent:@"X menu DOM diagnostic" detail:detail ?: @"" url:self.webView.URL];
    }
}
- (void)openSettings {
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[SettingsViewController new]];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation { [[DiagnosticsStore shared] addEvent:@"Navigation started" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { [[DiagnosticsStore shared] addEvent:@"Navigation finished" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [[DiagnosticsStore shared] addError:@"Provisional navigation failed" error:error url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { [[DiagnosticsStore shared] addError:@"Navigation failed" error:error url:webView.URL]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { [[DiagnosticsStore shared] addEvent:@"Web content process terminated" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)a decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url=a.request.URL; NSString *s=url.scheme.lowercaseString;
    if([self isWebURL:url]||[s isEqual:@"about"]||[s isEqual:@"blob"]||[s isEqual:@"data"]) { decisionHandler(WKNavigationActionPolicyAllow); return; }
    if ([s isEqual:@"x-safari-https"]) {
        [[DiagnosticsStore shared] addEvent:@"Intercepted x-safari-https"
                                    detail:@"Navigation cancelled to prevent redirect loop"
                                       url:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    [[DiagnosticsStore shared] addEvent:@"Blocked scheme" detail:s ?: @"" url:url];
    decisionHandler(WKNavigationActionPolicyCancel);
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)a windowFeatures:(WKWindowFeatures *)windowFeatures {
    if(a.targetFrame==nil&&a.request.URL)[webView loadRequest:a.request]; return nil;
}
@end
