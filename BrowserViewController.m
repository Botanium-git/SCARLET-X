#import "BrowserViewController.h"
#import "SettingsViewController.h"
#import "DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@property(nonatomic,assign) CFTimeInterval navigationStartTime;
@property(nonatomic,assign) CFTimeInterval requestStartTime;
@property(nonatomic,assign) NSInteger navigationSession;
@property(nonatomic,assign) BOOL requestPending;
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

    // Lightweight startup timing plus the proven Pull-to-Refresh header repair.
    // The large investigation probes from v1.0.8-v1.0.25 were removed after
    // the repair timing was confirmed on-device.
    NSString *performanceScript = @"(function(){"
      "if(window.__scarletXPerformanceInstalled)return;"
      "window.__scarletXPerformanceInstalled=true;"
      "function send(stage,extra){try{window.webkit.messageHandlers.scarletx.postMessage({type:'performance',stage:stage,now:Math.round(performance.now()),extra:extra||{}});}catch(e){}}"
      "var interactionBaseline=null;"
      "function compactSummary(){var types={};Object.keys(resourceSummary.byType).forEach(function(k){var b=resourceSummary.byType[k];types[k]={count:b.count,totalDuration:b.totalDuration,maxDuration:b.maxDuration};});return {count:resourceSummary.count,totalDuration:resourceSummary.totalDuration,maxDuration:resourceSummary.maxDuration,byType:types};}"
      "document.addEventListener('touchend',function(){interactionBaseline={at:Math.round(performance.now()),summary:compactSummary()};setTimeout(function(){if(!interactionBaseline)return;var now=compactSummary(),before=interactionBaseline.summary,deltaTypes={};Object.keys(now.byType).forEach(function(k){var n=now.byType[k],b=before.byType[k]||{count:0,totalDuration:0,maxDuration:0};var dc=n.count-b.count,dd=n.totalDuration-b.totalDuration;if(dc>0||dd>0)deltaTypes[k]={count:dc,totalDuration:dd,maxDuration:n.maxDuration};});var dc=now.count-before.count,dd=now.totalDuration-before.totalDuration;if(dc>0)send('post-interaction-resources',{interactionAt:interactionBaseline.at,windowMs:1000,resourceCount:dc,totalResourceDuration:dd,byType:deltaTypes});interactionBaseline=null;},1000);},{passive:true,capture:true});"
      "if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',function(){send('dom-content-loaded');},{once:true});}else{send('dom-content-loaded-already');}"
      "if(document.readyState==='complete'){send('window-load-already');}else{window.addEventListener('load',function(){send('window-load');},{once:true});}"
      "var resourceSummary={count:0,totalDuration:0,maxDuration:0,byType:{}},xhrTimeline=[];"
      "function noteResource(e){if(!e)return;var d=Math.max(0,Math.round(e.duration||0)),type=e.initiatorType||'other';resourceSummary.count++;resourceSummary.totalDuration+=d;if(d>resourceSummary.maxDuration)resourceSummary.maxDuration=d;var bucket=resourceSummary.byType[type]||(resourceSummary.byType[type]={count:0,totalDuration:0,maxDuration:0});bucket.count++;bucket.totalDuration+=d;if(d>bucket.maxDuration)bucket.maxDuration=d;if(type==='xmlhttprequest'&&xhrTimeline.length<40){xhrTimeline.push({id:xhrTimeline.length+1,start:Math.round(e.startTime||0),end:Math.round((e.startTime||0)+(e.duration||0)),duration:d});}}"
      "try{performance.getEntriesByType('resource').forEach(noteResource);new PerformanceObserver(function(list){list.getEntries().forEach(noteResource);}).observe({type:'resource',buffered:false});}catch(e){}"
      "function resourceSnapshot(stage){var types={};Object.keys(resourceSummary.byType).forEach(function(k){var b=resourceSummary.byType[k];types[k]={count:b.count,totalDuration:b.totalDuration,maxDuration:b.maxDuration};});send(stage,{resourceCount:resourceSummary.count,totalResourceDuration:resourceSummary.totalDuration,maxResourceDuration:resourceSummary.maxDuration,byType:types,xhrTimeline:xhrTimeline.slice()});}"
      "setTimeout(function(){resourceSnapshot('resource-summary-1500ms');},1500);"
      "setTimeout(function(){resourceSnapshot('resource-summary-3000ms');},3000);"
      "var mainSent=false,postSent=false;"
      "function inspect(){"
        "if(!mainSent){var main=document.querySelector('main,[role=\\\"main\\\"],[data-testid=\\\"primaryColumn\\\"]');if(main&&main.getBoundingClientRect().height>40){mainSent=true;send('x-main-visible',{tag:main.tagName,testid:main.getAttribute('data-testid')||''});}}"
        "if(!postSent){var post=document.querySelector('article[data-testid=\\\"tweet\\\"],article');if(post){var r=post.getBoundingClientRect(),text=(post.innerText||'').trim();if(r.height>40&&text.length>0){postSent=true;var types={};Object.keys(resourceSummary.byType).forEach(function(k){var b=resourceSummary.byType[k];types[k]={count:b.count,totalDuration:b.totalDuration,maxDuration:b.maxDuration};});send('first-post-visible',{y:Math.round(r.y),h:Math.round(r.height),textLength:text.length,resources:{count:resourceSummary.count,totalDuration:resourceSummary.totalDuration,maxDuration:resourceSummary.maxDuration,byType:types,xhrTimeline:xhrTimeline.slice()}});}}}"
        "if(mainSent&&postSent)observer.disconnect();"
      "}"
      "var observer=new MutationObserver(inspect);observer.observe(document.documentElement,{childList:true,subtree:true});inspect();"
      "var touch=null,pullCancelArmed=false;"
      "function forceXPortalLayerPulse(){var layers=document.getElementById('layers');if(!layers)return;var old=document.getElementById('scarletx-x-portal-probe');if(old)old.remove();var outer=document.createElement('div');outer.id='scarletx-x-portal-probe';outer.setAttribute('aria-hidden','true');outer.className='css-g5y9jx r-aqfbo4 r-zchlnj r-1d2f490 r-1xcajam r-12vffkv';outer.style.pointerEvents='none';var rel1=document.createElement('div');rel1.className='css-g5y9jx r-12vffkv';var rel2=document.createElement('div');rel2.className='css-g5y9jx r-12vffkv';var group=document.createElement('div');group.className='css-g5y9jx r-1ny4l3l';var rel3=document.createElement('div');rel3.className='css-g5y9jx r-16y2uox r-1wbh5a2';var fixed=document.createElement('div');fixed.className='css-g5y9jx r-1p0dtai r-1d2f490 r-1xcajam r-zchlnj r-ipm5af r-1j63xyz r-z2knda r-11z020y r-7qv4eb r-1habvwh';fixed.style.cssText+=';pointer-events:none!important;background:transparent!important;background-color:transparent!important;box-shadow:none!important;';outer.style.cssText+=';background:transparent!important;background-color:transparent!important;';rel1.style.background='transparent';rel2.style.background='transparent';group.style.background='transparent';rel3.style.background='transparent';var marker=document.createElement('div');marker.style.cssText='width:1px;height:1px;opacity:0;pointer-events:none;background:transparent!important';fixed.appendChild(marker);rel3.appendChild(fixed);group.appendChild(rel3);rel2.appendChild(group);rel1.appendChild(rel2);outer.appendChild(rel1);layers.appendChild(outer);void fixed.offsetHeight;requestAnimationFrame(function(){requestAnimationFrame(function(){setTimeout(function(){outer.remove();void layers.offsetHeight;send('header-repair-complete',{scrollY:Math.round(window.scrollY*100)/100,holdMs:120,visual:'transparent-override'});},120);});});}"
      "document.addEventListener('touchstart',function(e){if(e.touches.length!==1)return;var t=e.touches[0];touch={startY:t.clientY,lastY:t.clientY,startScrollY:window.scrollY,maxDown:0,repairOnDrag:pullCancelArmed};},{passive:true,capture:true});"
      "document.addEventListener('touchmove',function(e){if(!touch||e.touches.length!==1)return;var y=e.touches[0].clientY;touch.lastY=y;var d=y-touch.startY;if(d>touch.maxDown)touch.maxDown=d;if(touch.repairOnDrag&&!touch.repairTriggered&&Math.abs(d)>=8){touch.repairTriggered=true;pullCancelArmed=false;send('header-repair-triggered',{fingerDeltaY:Math.round(d),scrollY:Math.round(window.scrollY*100)/100});forceXPortalLayerPulse();}},{passive:true,capture:true});"
      "document.addEventListener('touchend',function(){if(!touch)return;var wasTopPull=touch.startScrollY<=120&&touch.maxDown>=20;if(wasTopPull){pullCancelArmed=true;send('header-repair-armed',{scrollY:Math.round(window.scrollY*100)/100});}touch=null;},{passive:true,capture:true});"
      "document.addEventListener('touchcancel',function(){touch=null;},{passive:true,capture:true});"
    "})();";
    WKUserScript *performanceUserScript = [[WKUserScript alloc] initWithSource:performanceScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [contentController addUserScript:performanceUserScript];
    config.userContentController = contentController;
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    // Raw WKWebView UA makes X redirect through x-safari-https; keep the verified Chrome-like iOS UA.
    self.webView.customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1";
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;

    // Keep a lightweight identity diagnostic because UA behavior is critical to X navigation.
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
    self.requestStartTime = CACurrentMediaTime();
    self.requestPending = YES;
    self.navigationStartTime = 0;
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
        CFTimeInterval requestElapsed = self.requestStartTime > 0 ? (CACurrentMediaTime() - self.requestStartTime) * 1000.0 : 0;
        NSDictionary *extra = [body[@"extra"] isKindOfClass:NSDictionary.class] ? body[@"extra"] : @{};
        NSData *extraData = [NSJSONSerialization dataWithJSONObject:extra options:0 error:nil];
        NSString *extraJSON = extraData ? [[NSString alloc] initWithData:extraData encoding:NSUTF8StringEncoding] : @"{}";
        NSString *detail = [NSString stringWithFormat:@"Stage: %@\nSession: %ld\nNavigation elapsed: %.0f ms\nRequest elapsed: %.0f ms\nPage performance.now: %@ ms\nReason: %@\nExtra: %@",
                            body[@"stage"] ?: @"", (long)self.navigationSession, elapsed, requestElapsed, body[@"now"] ?: @0, self.navigationReason ?: @"", extraJSON ?: @"{}"];
        [[DiagnosticsStore shared] addEvent:@"Page performance" detail:detail url:self.webView.URL];
    }
}
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
