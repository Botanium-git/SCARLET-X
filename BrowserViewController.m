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
      "var mainSent=false,postSent=false,lastY=window.scrollY,lastSample=0,lastDirection='none',headerState='unknown';"
      "function inspect(){"
        "if(!mainSent){var main=document.querySelector('main,[role=\"main\"],[data-testid=\"primaryColumn\"]');if(main&&main.getBoundingClientRect().height>40){mainSent=true;send('x-main-visible',{tag:main.tagName,testid:main.getAttribute('data-testid')||''});}}"
        "if(!postSent){var post=document.querySelector('article[data-testid=\"tweet\"],article');if(post){var r=post.getBoundingClientRect();var text=(post.innerText||'').trim();if(r.height>40&&text.length>0){postSent=true;send('first-post-visible',{y:Math.round(r.y),h:Math.round(r.height),textLength:text.length});}}}"
        "if(mainSent&&postSent)observer.disconnect();"
      "}"
      "function findHomeHeader(){var tabs=[].slice.call(document.querySelectorAll('[role=\"tab\"]'));var t=tabs.find(function(e){var s=(e.innerText||'').trim();return s==='おすすめ'||s==='フォロー中'||s==='For you'||s==='Following';});return t?t.parentElement:null;}"
      "function sampleScroll(){var y=window.scrollY,dy=y-lastY;if(Math.abs(dy)>=2)lastDirection=dy<0?'toward-top':'toward-bottom';lastY=y;var now=performance.now();if(now-lastSample<300)return;lastSample=now;var h=findHomeHeader();if(!h)return;var r=h.getBoundingClientRect();var visible=r.bottom>0&&r.top<window.innerHeight;var state=visible?'visible':'hidden';if(state!==headerState||Math.abs(dy)>=40){headerState=state;send('home-header-scroll',{scrollY:Math.round(y),deltaY:Math.round(dy),direction:lastDirection,headerVisible:visible,headerY:Math.round(r.y),headerH:Math.round(r.height)});}}"
      "var observer=new MutationObserver(inspect);observer.observe(document.documentElement,{childList:true,subtree:true});inspect();"
      "window.addEventListener('scroll',sampleScroll,{passive:true});"
      "var touch=null;"
      "function headerInfo(){var h=findHomeHeader();if(!h)return {found:false};var r=h.getBoundingClientRect();return {found:true,visible:r.bottom>0&&r.top<window.innerHeight,y:Math.round(r.y),h:Math.round(r.height)};}"
      "var layoutLastAt=0,layoutLastKey='',transitionState=null;"
      "function nodeSnapshot(el,level){if(!el)return null;var r=el.getBoundingClientRect(),s=getComputedStyle(el);return {level:level,tag:el.tagName,id:el.id||'',testid:el.getAttribute('data-testid')||'',role:el.getAttribute('role')||'',className:typeof el.className==='string'?el.className.slice(0,240):'',rect:{x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height),top:Math.round(r.top),bottom:Math.round(r.bottom)},css:{display:s.display,position:s.position,top:s.top,bottom:s.bottom,transform:s.transform,translate:s.translate,transition:s.transition,overflow:s.overflow,overflowY:s.overflowY},style:(el.getAttribute('style')||'').slice(0,300)};}"
      "function headerChain(h){var chain=[],el=h;for(var i=0;i<16&&el;i++,el=el.parentElement)chain.push(nodeSnapshot(el,i));return chain;}"
      "function sendHeaderLayout(trigger,force){var h=findHomeHeader();if(!h)return;var now=performance.now(),r=h.getBoundingClientRect(),y=window.scrollY;var key=Math.round(y)+'|'+Math.round(r.y);if(!force&&now-layoutLastAt<120)return;if(!force&&key===layoutLastKey)return;layoutLastAt=now;layoutLastKey=key;send('home-header-layout',{trigger:trigger,scrollY:Math.round(y),headerY:Math.round(r.y),headerH:Math.round(r.height),viewportH:window.innerHeight,chain:headerChain(h)});}"
      "function inspectHeaderTransition(source){var h=findHomeHeader();if(!h)return;var r=h.getBoundingClientRect(),visible=r.bottom>0&&r.top<window.innerHeight,y=Math.round(r.y),state=(visible?'v':'h')+'|'+y;if(transitionState===null){transitionState=state;return;}if(state===transitionState)return;var previous=transitionState;transitionState=state;var fingerDelta=null,touchAge=null;if(touch){fingerDelta=Math.round(touch.lastY-touch.startY);touchAge=Math.round(performance.now()-touch.startTime);}send('home-header-transition',{source:source,previous:previous,current:state,scrollY:Math.round(window.scrollY),headerY:y,headerH:Math.round(r.height),headerVisible:visible,fingerDeltaY:fingerDelta,touchAgeMs:touchAge,chain:headerChain(h)});}"
      "var traceActive=false,traceRAF=0,traceStart=0,traceLast=0,traceSeq=0;"
      "function findTopNavBar(){return document.querySelector('[data-testid=\"TopNavBar\"]');}"
      "function matrixTranslateY(transform){if(!transform||transform==='none')return 0;var m=transform.match(/^matrix\\([^,]+,[^,]+,[^,]+,[^,]+,[^,]+,\\s*([^\\)]+)\\)$/);if(m)return Math.round(parseFloat(m[1])*100)/100;var m3=transform.match(/^matrix3d\\((.+)\\)$/);if(m3){var p=m3[1].split(',');if(p.length===16)return Math.round(parseFloat(p[13])*100)/100;}return null;}"
      "function traceSample(force){if(!traceActive)return;var now=performance.now();if(!force&&now-traceLast<32){traceRAF=requestAnimationFrame(function(){traceSample(false);});return;}traceLast=now;var nav=findTopNavBar();if(nav){var nr=nav.getBoundingClientRect(),ns=getComputedStyle(nav),parent=nav.parentElement,pr=parent?parent.getBoundingClientRect():null,ps=parent?getComputedStyle(parent):null,vv=window.visualViewport;send('home-header-trace',{seq:++traceSeq,elapsedMs:Math.round(now-traceStart),scrollY:Math.round(window.scrollY*100)/100,topNavY:Math.round(nr.y*100)/100,topNavH:Math.round(nr.height*100)/100,transformY:matrixTranslateY(ns.transform),transform:ns.transform,fixedParentY:pr?Math.round(pr.y*100)/100:null,fixedParentH:pr?Math.round(pr.height*100)/100:null,fixedParentPosition:ps?ps.position:null,fixedParentTransform:ps?ps.transform:null,viewportOffsetTop:vv?Math.round(vv.offsetTop*100)/100:null,viewportPageTop:vv?Math.round(vv.pageTop*100)/100:null,viewportH:vv?Math.round(vv.height*100)/100:null});}if(now-traceStart<1800){traceRAF=requestAnimationFrame(function(){traceSample(false);});}else{traceActive=false;traceRAF=0;send('home-header-trace-end',{samples:traceSeq});}}"
      "function startHeaderTrace(){if(traceRAF)cancelAnimationFrame(traceRAF);traceActive=true;traceStart=performance.now();traceLast=0;traceSeq=0;send('home-header-trace-start',{scrollY:Math.round(window.scrollY*100)/100});traceSample(true);}"
      "var topZone=false;function inspectTopBoundary(){var y=window.scrollY,near=y<=120;if(near&&!topZone){topZone=true;sendHeaderLayout('entered-top-zone',true);}else if(!near&&topZone){topZone=false;sendHeaderLayout('left-top-zone',true);}else if(near){sendHeaderLayout('top-zone-scroll',false);}}"
      "window.addEventListener('scroll',inspectTopBoundary,{passive:true});"
      "window.addEventListener('scroll',function(){inspectHeaderTransition('scroll');},{passive:true});"
      "setTimeout(function(){inspectTopBoundary();sendHeaderLayout('initial-layout',true);},0);"
      "document.addEventListener('touchstart',function(e){if(e.touches.length!==1)return;var t=e.touches[0];touch={startY:t.clientY,lastY:t.clientY,startTime:performance.now(),startScrollY:window.scrollY,startHeader:headerInfo(),maxDown:0,maxUp:0};startHeaderTrace();if(window.scrollY<=120)sendHeaderLayout('top-zone-touchstart',true);},{passive:true,capture:true});"
      "document.addEventListener('touchmove',function(e){if(!touch||e.touches.length!==1)return;var y=e.touches[0].clientY;touch.lastY=y;var d=y-touch.startY;if(d>touch.maxDown)touch.maxDown=d;if(d<touch.maxUp)touch.maxUp=d;inspectHeaderTransition('touchmove');},{passive:true,capture:true});"
      "document.addEventListener('touchend',function(){if(!touch)return;var duration=Math.round(performance.now()-touch.startTime),fingerDelta=Math.round(touch.lastY-touch.startY),end=headerInfo();if(Math.abs(fingerDelta)>=8||touch.startHeader.visible!==end.visible){send('home-header-touch',{fingerDeltaY:fingerDelta,maxFingerDown:Math.round(touch.maxDown),maxFingerUp:Math.round(touch.maxUp),durationMs:duration,startScrollY:Math.round(touch.startScrollY),endScrollY:Math.round(window.scrollY),startHeaderVisible:touch.startHeader.visible===true,endHeaderVisible:end.visible===true,startHeaderY:touch.startHeader.y==null?null:touch.startHeader.y,endHeaderY:end.y==null?null:end.y});}if(touch.startScrollY<=120||window.scrollY<=120){sendHeaderLayout('top-zone-touchend',true);setTimeout(function(){sendHeaderLayout('top-zone-after-touch-150ms',true);},150);setTimeout(function(){sendHeaderLayout('top-zone-after-touch-400ms',true);},400);}touch=null;},{passive:true,capture:true});"
      "document.addEventListener('touchcancel',function(){touch=null;},{passive:true,capture:true});"
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
        NSDictionary *extra = [body[@"extra"] isKindOfClass:NSDictionary.class] ? body[@"extra"] : @{};
        NSData *extraData = [NSJSONSerialization dataWithJSONObject:extra options:0 error:nil];
        NSString *extraJSON = extraData ? [[NSString alloc] initWithData:extraData encoding:NSUTF8StringEncoding] : @"{}";
        NSString *detail = [NSString stringWithFormat:@"Stage: %@\nNative elapsed: %.0f ms\nPage performance.now: %@ ms\nReason: %@\nExtra: %@",
                            body[@"stage"] ?: @"", elapsed, body[@"now"] ?: @0, self.navigationReason ?: @"", extraJSON ?: @"{}"];
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
