#import "BrowserViewController.h"
#import "SettingsViewController.h"
#import "DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@property(nonatomic,assign) CFTimeInterval navigationStartTime;
@property(nonatomic,copy) NSString *navigationReason;
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
        "function add(){"
          "if(document.getElementById('scarletx-settings-item'))return;"
          "var candidates=[].slice.call(document.querySelectorAll('a[href=\"/settings\"],a[href=\"/settings/account\"]'));"
          "var anchor=candidates.find(function(a){return (a.innerText||'').indexOf('設定とプライバシー')!==-1;})||candidates[0];"
          "if(!anchor)return;"
          "var row=anchor.parentElement;"
          "var list=row&&row.parentElement;"
          "if(!row||!list)return;"
          "var item=row.cloneNode(true);"
          "item.id='scarletx-settings-item';"
          "var link=item.querySelector('a[href=\"/settings\"],a[href=\"/settings/account\"]')||(item.matches&&item.matches('a')?item:null);"
          "if(link){link.removeAttribute('href');link.setAttribute('role','button');}"
          "var walker=document.createTreeWalker(item,NodeFilter.SHOW_TEXT);"
          "var node;"
          "while((node=walker.nextNode())){if(node.nodeValue&&node.nodeValue.indexOf('設定とプライバシー')!==-1){node.nodeValue=node.nodeValue.replace('設定とプライバシー','Scarlet X 設定');break;}}"
          "item.addEventListener('click',function(e){e.preventDefault();e.stopPropagation();window.webkit.messageHandlers.scarletx.postMessage('settings');},true);"
          "list.insertBefore(item,row.nextSibling);"
        "}"
        "new MutationObserver(add).observe(document.documentElement,{childList:true,subtree:true});"
        "add();"
      "})();";
    WKUserScript *script = [[WKUserScript alloc] initWithSource:settingsScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [contentController addUserScript:script];

    NSString *performanceScript = @"(function(){"
      "if(window.__scarletXPerformanceInstalled)return;"
      "window.__scarletXPerformanceInstalled=true;"
      "function send(stage,extra){try{window.webkit.messageHandlers.scarletx.postMessage({type:'performance',stage:stage,now:Math.round(performance.now()),extra:extra||{}});}catch(e){}}"
      "if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',function(){send('dom-content-loaded');},{once:true});}else{send('dom-content-loaded-already');}"
      "if(document.readyState==='complete'){send('window-load-already');}else{window.addEventListener('load',function(){send('window-load');},{once:true});}"
      "var first=false;"
      "function visible(){if(first)return;var main=document.querySelector('main,[role=\"main\"],[data-testid=\"primaryColumn\"]');if(main&&main.getBoundingClientRect().height>40){first=true;send('x-main-visible',{tag:main.tagName,testid:main.getAttribute('data-testid')||''});observer.disconnect();}}"
      "var observer=new MutationObserver(visible);observer.observe(document.documentElement,{childList:true,subtree:true});visible();"
    "})();";
    WKUserScript *performanceUserScript = [[WKUserScript alloc] initWithSource:performanceScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [contentController addUserScript:performanceUserScript];
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
    self.navigationStartTime = CACurrentMediaTime();
    self.navigationReason = reason ?: @"";
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}
- (void)goHome { [self loadURL:[NSURL URLWithString:@"https://x.com/home"] reason:@"Home"]; }
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx"]) return;
    if ([message.body isEqual:@"settings"]) {
        [self openSettings];
        return;
    }
    if ([message.body isKindOfClass:NSDictionary.class] && [message.body[@"type"] isEqual:@"performance"]) {
        NSDictionary *body = message.body;
        CFTimeInterval elapsed = self.navigationStartTime > 0 ? (CACurrentMediaTime() - self.navigationStartTime) * 1000.0 : 0;
        NSString *detail = [NSString stringWithFormat:@"Stage: %@\nNative elapsed: %.0f ms\nPage performance.now: %@ ms\nReason: %@",
                            body[@"stage"] ?: @"", elapsed, body[@"now"] ?: @0, self.navigationReason ?: @""];
        [[DiagnosticsStore shared] addEvent:@"Page performance" detail:detail url:self.webView.URL];
    }
}
- (void)openSettings {
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[SettingsViewController new]];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation { if (self.navigationStartTime <= 0) self.navigationStartTime = CACurrentMediaTime(); [[DiagnosticsStore shared] addEvent:@"Navigation started" detail:self.navigationReason ?: @"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { CFTimeInterval elapsed = self.navigationStartTime > 0 ? (CACurrentMediaTime() - self.navigationStartTime) * 1000.0 : 0; NSString *detail=[NSString stringWithFormat:@"%.0f ms | %@", elapsed, self.navigationReason ?: @""]; [[DiagnosticsStore shared] addEvent:@"Navigation finished" detail:detail url:webView.URL]; }
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
