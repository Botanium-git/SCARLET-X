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
    BOOL needsOfficialRoute = nativeDrawer && ([path isEqual:@"/i/bookmarks"] || [path isEqual:@"/lists"] || [path hasPrefix:@"/settings"]);
    if(needsOfficialRoute){
        NSString *target=[path isEqual:@"/i/bookmarks"]?@"history":([path isEqual:@"/lists"]?@"lists":@"settings");
        NSString *script=[NSString stringWithFormat:@"(function(){return new Promise(function(resolve){var target='%@';var profile=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');if(!profile){resolve({ok:false,reason:'profile-not-found',target:target});return;}function textOf(el){return ((el.innerText||el.textContent||'')+'').trim();}function matches(el){var t=textOf(el).toLowerCase();if(target==='history')return t==='履歴'||t==='ブックマーク'||t==='history'||t==='bookmarks';if(target==='lists')return t==='リスト'||t==='lists';if(target==='settings')return t==='設定とプライバシー'||t==='settings and privacy'||t==='settings';return false;}function clickMatch(){var nodes=Array.from(document.querySelectorAll('a[href],button,[role=menuitem]'));var hit=nodes.find(matches);if(hit){var href=hit.getAttribute&&hit.getAttribute('href')||'';hit.click();resolve({ok:true,target:target,text:textOf(hit),href:href,url:location.href});return true;}return false;}try{profile.click();}catch(e){resolve({ok:false,reason:'profile-click-failed',error:String(e),target:target});return;}setTimeout(function(){if(clickMatch())return;if(target==='settings'){var nodes=Array.from(document.querySelectorAll('button,[role=menuitem]'));var parent=nodes.find(function(el){var t=textOf(el).toLowerCase();return t==='設定とプライバシー'||t==='settings and privacy';});if(parent){try{parent.click();}catch(e){}setTimeout(function(){if(clickMatch())return;var links=Array.from(document.querySelectorAll('a[href]')).map(function(a){return {text:textOf(a).slice(0,120),href:a.getAttribute('href')||''};}).filter(function(x){return /settings/i.test(x.href)||/設定|settings/i.test(x.text);}).slice(0,20);resolve({ok:false,reason:'settings-target-not-found',target:target,links:links,url:location.href});},250);return;}}var links=Array.from(document.querySelectorAll('a[href]')).map(function(a){return {text:textOf(a).slice(0,120),href:a.getAttribute('href')||''};}).filter(function(x){return /bookmark|history|list|settings/i.test(x.href)||/履歴|ブックマーク|リスト|設定|history|bookmarks|lists|settings/i.test(x.text);}).slice(0,30);resolve({ok:false,reason:'target-not-found',target:target,links:links,url:location.href});},300);});})()",target];
        __weak typeof(self) weakSelf=self;
        [self.webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
            typeof(self) self=weakSelf; if(!self)return;
            if(error){
                [[DiagnosticsStore shared] addError:@"Native drawer official route failed" error:error url:self.webView.URL];
                return;
            }
            NSData *data=[NSJSONSerialization dataWithJSONObject:result?:@{} options:0 error:nil];
            NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[result description];
            [[DiagnosticsStore shared] addEvent:@"Native drawer official route" detail:detail?:@"" url:self.webView.URL];
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
