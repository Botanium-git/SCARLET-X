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
    // Intentionally empty. Quick log export now lives on a long press of the X home button.
}

- (void)sx_quickLog_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self sx_quickLog_webView:webView didFinishNavigation:navigation];

    NSString *script = @"(function(){"
        "if(window.__scarletXLongPressLogInstalled)return;"
        "window.__scarletXLongPressLogInstalled=true;"
        "var timer=null,target=null,fired=false,suppressHomeClickUntil=0;"
        "function homeFromEvent(e){var n=e&&e.target;return n&&n.closest?n.closest('a[href=\"/home\"]'):null;}"
        "function clear(){if(timer){clearTimeout(timer);timer=null;}target=null;}"
        "document.addEventListener('touchstart',function(e){"
            "var p=homeFromEvent(e);if(!p)return;clear();target=p;fired=false;"
            "timer=setTimeout(function(){timer=null;if(!target)return;fired=true;suppressHomeClickUntil=Date.now()+1200;"
                "try{window.webkit.messageHandlers.scarletx.postMessage({type:'quick-log-export'});}catch(_){}"
            "},600);"
        "},{capture:true,passive:false});"
        "document.addEventListener('touchmove',function(e){if(target&&!fired)clear();},{capture:true,passive:false});"
        "document.addEventListener('touchcancel',function(){clear();fired=false;},{capture:true,passive:false});"
        "document.addEventListener('touchend',function(e){"
            "if(!target)return;var consumed=fired;clear();"
            "if(consumed){e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();}"
            "fired=false;"
        "},{capture:true,passive:false});"
        "document.addEventListener('click',function(e){var p=homeFromEvent(e);if(!p||Date.now()>=suppressHomeClickUntil)return;suppressHomeClickUntil=0;e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();},true);"
        "document.addEventListener('contextmenu',function(e){if(homeFromEvent(e)&&Date.now()<suppressHomeClickUntil){e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();}},true);"
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
            [[DiagnosticsStore shared] addEvent:@"Quick log export" detail:@"Home button long press" url:nil];
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

    NSString *script = @"(function(){"
        "function info(el){if(!el)return null;var s=getComputedStyle(el),r=el.getBoundingClientRect(),a=el.closest&&el.closest('a');return {tag:el.tagName||'',text:(el.innerText||el.textContent||'').replace(/\\s+/g,' ').trim().slice(0,80),fontSize:s.fontSize||'',lineHeight:s.lineHeight||'',fontWeight:s.fontWeight||'',fontFamily:s.fontFamily||'',display:s.display||'',href:a?(a.getAttribute('href')||''):'',aria:el.getAttribute?el.getAttribute('aria-label')||'':'',testid:el.getAttribute?el.getAttribute('data-testid')||'':'',rect:{x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.width),height:Math.round(r.height)}};}"
        "function box(el){if(!el)return null;var s=getComputedStyle(el),r=el.getBoundingClientRect();return {tag:el.tagName||'',testid:el.getAttribute?el.getAttribute('data-testid')||'':'',className:typeof el.className==='string'?el.className.slice(0,180):'',rect:{x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.width),height:Math.round(r.height)},width:s.width||'',height:s.height||'',minWidth:s.minWidth||'',maxWidth:s.maxWidth||'',minHeight:s.minHeight||'',maxHeight:s.maxHeight||'',aspectRatio:s.aspectRatio||'',paddingTop:s.paddingTop||'',paddingRight:s.paddingRight||'',paddingBottom:s.paddingBottom||'',paddingLeft:s.paddingLeft||'',display:s.display||'',position:s.position||'',overflow:s.overflow||'',overflowX:s.overflowX||'',overflowY:s.overflowY||'',flex:s.flex||'',flexBasis:s.flexBasis||'',alignSelf:s.alignSelf||'',objectFit:s.objectFit||'',objectPosition:s.objectPosition||'',borderRadius:s.borderRadius||'',inlineStyle:el.getAttribute?el.getAttribute('style')||'':''};}"
        "function infos(root,sel,limit){if(!root)return[];return Array.from(root.querySelectorAll(sel)).slice(0,limit||40).map(info);}"
        "var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');var img=p&&p.querySelector('img');var dialogs=document.querySelectorAll('[role=dialog],[role=menu]');var buttons=document.querySelectorAll('button[aria-label$=\"に切り替える\"]');"
        "var articles=Array.from(document.querySelectorAll('article[data-testid=\"tweet\"]'));var main=articles.find(function(a){return !!a.querySelector('[data-testid=\"tweetText\"]');})||articles[0]||null;"
        "var un=main&&main.querySelector('[data-testid=\"User-Name\"]');var tw=main&&main.querySelector('[data-testid=\"tweetText\"]');var grp=main&&main.querySelector('[role=\"group\"]');"
        "var children=un?Array.from(un.querySelectorAll('*')).filter(function(e){return (e.innerText||e.textContent||'').trim()||e.tagName==='TIME'||e.tagName==='A';}).slice(0,30).map(info):[];"
        "var heads=Array.from(document.querySelectorAll('h1,h2,[role=\"heading\"]')).slice(0,12).map(info);"
        "var times=infos(main,'time',12);"
        "var actionNodes=grp?Array.from(grp.querySelectorAll('button,a,span,div')).filter(function(e){var t=(e.innerText||e.textContent||'').trim();var test=e.getAttribute&&e.getAttribute('data-testid');var aria=e.getAttribute&&e.getAttribute('aria-label');return t||test||aria;}).slice(0,80).map(info):[];"
        "var replyCandidates=main?Array.from(main.querySelectorAll('a,span,div')).filter(function(e){var t=(e.innerText||e.textContent||'').replace(/\\s+/g,' ').trim();return t&&(/返信先|Replying to|返信/.test(t));}).slice(0,20).map(info):[];"
        "var nestedArticles=main?Array.from(main.querySelectorAll('article[data-testid=\"tweet\"]')).filter(function(a){return a!==main;}).slice(0,6):[];"
        "var quoteCards=main?Array.from(main.querySelectorAll('[role=\"link\"],a')).filter(function(e){return !!e.querySelector&&!!e.querySelector('[data-testid=\"tweetText\"]');}).slice(0,8):[];"
        "var quoted=[];nestedArticles.concat(quoteCards).forEach(function(q){if(!q||quoted.indexOf(q)>=0)return;quoted.push(q);});"
        "var quotes=quoted.slice(0,8).map(function(q){var qu=q.querySelector('[data-testid=\"User-Name\"]'),qt=q.querySelector('[data-testid=\"tweetText\"]');return {container:info(q),userName:info(qu),userNameChildren:qu?Array.from(qu.querySelectorAll('*')).filter(function(e){return (e.innerText||e.textContent||'').trim()||e.tagName==='TIME'||e.tagName==='A';}).slice(0,20).map(info):[],tweetText:info(qt),times:infos(q,'time',6)};});"
        "var metaNodes=main?Array.from(main.querySelectorAll('a,span,div')).filter(function(e){var t=(e.innerText||e.textContent||'').replace(/\\s+/g,' ').trim();if(!t||t.length>120)return false;return /表示|閲覧|Views|午後|午前|AM|PM|返信先|Replying to|経由|Translate|翻訳/.test(t);}).slice(0,40).map(info):[];"
        "var photo=main&&main.querySelector('[data-testid=\"tweetPhoto\"]');var mediaImg=photo&&photo.querySelector('img');var ancestors=[];for(var n=photo,i=0;n&&i<12;n=n.parentElement,i++){ancestors.push(box(n));if(n===main)break;}"
        "var mediaDesc=photo?Array.from(photo.querySelectorAll('*')).filter(function(e){var s=getComputedStyle(e);return e===mediaImg||s.position==='absolute'||(s.aspectRatio&&s.aspectRatio!=='auto')||(s.paddingBottom&&s.paddingBottom!=='0px')||e.hasAttribute('style');}).slice(0,40).map(box):[];"
        "var mediaImage=mediaImg?Object.assign(box(mediaImg),{naturalWidth:mediaImg.naturalWidth||0,naturalHeight:mediaImg.naturalHeight||0,complete:!!mediaImg.complete,currentSrc:(mediaImg.currentSrc||'').slice(0,180)}):null;"
        "return {probe:'closed-dom',profileExists:!!p,profileExpanded:p?(p.getAttribute('aria-expanded')||''):'',profileLabel:p?(p.getAttribute('aria-label')||''):'',profileImage:img?(img.currentSrc||img.src||''):'',dialogCount:dialogs.length,switchButtonCount:buttons.length,switchLabels:Array.from(buttons).map(function(b){return b.getAttribute('aria-label')||'';}),typography:{route:location.pathname,userName:info(un),userNameChildren:children,tweetText:info(tw),actionGroup:info(grp),actionNodes:actionNodes,times:times,replyCandidates:replyCandidates,quotes:quotes,metaNodes:metaNodes,headings:heads,viewport:{innerWidth:innerWidth,innerHeight:innerHeight,dpr:devicePixelRatio,visualScale:window.visualViewport?window.visualViewport.scale:null}},media:{photo:box(photo),image:mediaImage,ancestors:ancestors,descendants:mediaDesc}};"
    "})()";
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
