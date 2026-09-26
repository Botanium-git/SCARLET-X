#import "BrowserViewController+Navigation.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>

@interface BrowserViewController ()
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@property(nonatomic,assign) CFTimeInterval navigationStartTime;
@property(nonatomic,assign) CFTimeInterval requestStartTime;
@property(nonatomic,assign) NSInteger navigationSession;
@property(nonatomic,assign) BOOL requestPending;
@property(nonatomic,copy) NSString *navigationReason;
@end

@implementation BrowserViewController (Navigation)
- (BOOL)isWebURL:(NSURL *)url { NSString *s=url.scheme.lowercaseString; return [s isEqual:@"https"]||[s isEqual:@"http"]; }
- (NSURL *)unwrapScarletURL:(NSURL *)url {
    if (![[url.scheme lowercaseString] isEqual:@"scarletx"]) return url;
    NSURLComponents *c=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *i in c.queryItems) if ([i.name isEqual:@"url"]&&i.value.length) { NSURL *u=[NSURL URLWithString:i.value]; if(u)return u; }
    return [NSURL URLWithString:@"https://x.com/"];
}
- (void)loadURL:(NSURL *)url reason:(NSString *)reason {
    if(![self isWebURL:url]) { [[DiagnosticsStore shared] addEvent:@"Unsupported URL" detail:url.scheme ?: @"" url:url]; return; }

    NSString *path=url.path ?: @"";
    BOOL nativeDrawer=[reason isEqual:@"Native drawer"];
    BOOL isHistory=[path isEqual:@"/i/bookmarks"]||[path isEqual:@"/i/history"];
    BOOL isLists=[path isEqual:@"/lists"]||[path isEqual:@"/i/lists"];
    BOOL isSettings=[path hasPrefix:@"/settings"];
    BOOL needsOfficialRoute=nativeDrawer&&(isHistory||isLists||isSettings);
    if(needsOfficialRoute){
        NSString *target=isHistory?@"history":(isLists?@"lists":@"settings");
        [[DiagnosticsStore shared] addEvent:@"Native drawer official route start" detail:[NSString stringWithFormat:@"target=%@ path=%@",target,path] url:self.webView.URL];
        NSString *script=[NSString stringWithFormat:@"(function(){var target='%@';function send(stage,extra){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'official-route '+stage+' '+JSON.stringify(extra||{})});}catch(_){}}function textOf(el){return ((el&& (el.innerText||el.textContent))||'').trim();}function meta(el){return {text:textOf(el).slice(0,160),href:(el&&el.getAttribute&&el.getAttribute('href'))||'',testid:(el&&el.getAttribute&&el.getAttribute('data-testid'))||'',aria:(el&&el.getAttribute&&el.getAttribute('aria-label'))||'',role:(el&&el.getAttribute&&el.getAttribute('role'))||''};}function score(el){var m=meta(el),t=m.text.toLowerCase(),h=m.href.toLowerCase(),a=m.aria.toLowerCase(),id=m.testid.toLowerCase(),s=0;if(target==='history'){if(/bookmark|history/.test(h))s+=10;if(/bookmark|history/.test(id))s+=8;if(/履歴|ブックマーク|history|bookmarks/.test(a))s+=6;if(/履歴|ブックマーク|history|bookmarks/.test(t))s+=4;}else if(target==='lists'){if(/(^|\/)i?\/?lists(?:\/|$)/.test(h))s+=10;if(/list/.test(id))s+=8;if(/リスト|lists/.test(a))s+=6;if(/リスト|lists/.test(t))s+=4;}else{if(/settings/.test(h))s+=10;if(/settings/.test(id))s+=8;if(/設定とプライバシー|settings and privacy|settings/.test(a))s+=6;if(/設定とプライバシー|settings and privacy|settings/.test(t))s+=4;}return s;}function candidates(){return Array.from(document.querySelectorAll('a[href],button,[role=menuitem]')).map(function(el){return {el:el,score:score(el),meta:meta(el)};}).filter(function(x){return x.score>0;}).sort(function(a,b){return b.score-a.score;});}var done=false,observer=null,timer=null;function finish(stage,payload){if(done)return;done=true;if(observer)observer.disconnect();if(timer)clearTimeout(timer);send(stage,payload);}function tryHit(){if(done)return true;var c=candidates();if(c.length){var hit=c[0];finish('hit',{target:target,score:hit.score,candidate:hit.meta,top:c.slice(0,8).map(function(x){return {score:x.score,meta:x.meta};})});try{hit.el.click();}catch(e){send('click-error',{target:target,error:String(e)});}return true;}return false;}var profile=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');if(!profile){finish('profile-not-found',{target:target,url:location.href});return null;}send('begin',{target:target,url:location.href});observer=new MutationObserver(function(){tryHit();});observer.observe(document.documentElement||document.body,{childList:true,subtree:true,attributes:true});try{profile.click();send('profile-clicked',{target:target});}catch(e){finish('profile-click-failed',{target:target,error:String(e)});return null;}setTimeout(tryHit,120);setTimeout(tryHit,350);setTimeout(tryHit,700);timer=setTimeout(function(){var c=candidates();finish('timeout',{target:target,url:location.href,top:c.slice(0,12).map(function(x){return {score:x.score,meta:x.meta};})});},3000);return null;})()",target];
        [self.webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
            if(error) [[DiagnosticsStore shared] addError:@"Native drawer official route injection failed" error:error url:self.webView.URL];
        }];
        return;
    }

    [[DiagnosticsStore shared] addEvent:@"Loading URL" detail:reason ?: @"" url:url];
    self.requestStartTime = CACurrentMediaTime();
    self.requestPending = YES;
    self.navigationStartTime = 0;
    self.navigationReason = reason ?: @"";
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}
- (void)goHome { [self loadURL:[NSURL URLWithString:@"https://x.com/home"] reason:@"Home"]; }
@end
