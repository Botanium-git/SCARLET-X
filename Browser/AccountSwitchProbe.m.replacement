#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (AccountSwitchOriginal)
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path;
@end

@implementation BrowserViewController (AccountSwitch)
static char SXSwitchingKey;
static char SXClickIssuedKey;
static char SXAttemptInFlightKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method a=class_getInstanceMethod(self,@selector(nativeDrawer:didSelectPath:));
        Method b=class_getInstanceMethod(self,@selector(sx_switch_nativeDrawer:didSelectPath:));
        if(a&&b)method_exchangeImplementations(a,b);
    });
}

- (void)sx_switch_nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    if(![path hasPrefix:@"/__scarletx_account_probe"]){ [self sx_switch_nativeDrawer:drawer didSelectPath:path]; return; }
    if([objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;

    NSURLComponents *c=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *target=@"";
    for(NSURLQueryItem *q in c.queryItems)if([q.name isEqual:@"screen_name"])target=q.value?:@"";
    if(!target.length)return;

    WKWebView *web=nil;
    @try { web=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![web isKindOfClass:WKWebView.class])return;

    objc_setAssociatedObject(self,&SXSwitchingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,&SXClickIssuedKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,&SXAttemptInFlightKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[DiagnosticsStore shared] addEvent:@"Account switch start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *trace=[NSString stringWithFormat:
        @"(function(){var target='%@';"
         "window.__scarletXSwitchTraceTarget=target;"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-transport '+JSON.stringify({kind:kind,target:window.__scarletXSwitchTraceTarget||'',href:location.href,data:data||{}})});}catch(_){}}"
         "if(!window.__scarletXSwitchTraceInstalled){window.__scarletXSwitchTraceInstalled=true;"
         "var op=history.pushState.bind(history);history.pushState=function(s,t,u){send('pushState',{url:String(u||'')});return op(s,t,u);};"
         "var orp=history.replaceState.bind(history);history.replaceState=function(s,t,u){send('replaceState',{url:String(u||'')});return orp(s,t,u);};"
         "var of=window.fetch;if(typeof of==='function'){window.fetch=function(input,init){var u='';try{u=typeof input==='string'?input:(input&&input.url)||String(input||'');}catch(_){}send('fetch',{url:u,method:(init&&init.method)||'GET'});return of.apply(this,arguments);};}"
         "var xo=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){send('xhr',{url:String(u||''),method:String(m||'GET')});return xo.apply(this,arguments);};"
         "addEventListener('popstate',function(){send('popstate',{});});"
         "addEventListener('hashchange',function(){send('hashchange',{});});"
         "addEventListener('pagehide',function(){send('pagehide',{});});"
         "addEventListener('beforeunload',function(){send('beforeunload',{});});"
         "}"
         "send('trace-installed',{});return true;})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:trace completionHandler:^(__unused id r,NSError *traceError){
        typeof(self) self=weakSelf;if(!self)return;
        if(traceError)[[DiagnosticsStore shared] addError:@"Account switch transport probe failed" error:traceError url:web.URL];

        NSString *open=@"(function(){var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');if(!p)return false;window.__scarletXNativeBypass=true;p.click();return true;})()";
        [web evaluateJavaScript:open completionHandler:^(id r,NSError *e){
            typeof(self) self=weakSelf;if(!self)return;
            if(e||![r boolValue]){objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}

            for(NSNumber *d in @[@0.2,@0.5,@1.0]){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    typeof(self) self=weakSelf;if(!self)return;
                    if(![objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;
                    if([objc_getAssociatedObject(self,&SXClickIssuedKey) boolValue])return;
                    if([objc_getAssociatedObject(self,&SXAttemptInFlightKey) boolValue])return;
                    objc_setAssociatedObject(self,&SXAttemptInFlightKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    NSString *js=[NSString stringWithFormat:@"(function(){var want='@%@に切り替える';var bs=Array.from(document.querySelectorAll('button'));var hit=bs.find(function(b){return (b.getAttribute('aria-label')||'')===want;});if(!hit)return {found:false};window.__scarletXNativeBypass=false;hit.click();return {found:true,aria:want};})()",escaped];
                    [web evaluateJavaScript:js completionHandler:^(id result,NSError *error){
                        typeof(self) self=weakSelf;if(!self)return;
                        objc_setAssociatedObject(self,&SXAttemptInFlightKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        if(error)return;
                        NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
                        if([dict[@"found"] boolValue]){
                            objc_setAssociatedObject(self,&SXClickIssuedKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                            [[DiagnosticsStore shared] addEvent:@"Account switch button clicked" detail:[NSString stringWithFormat:@"target=@%@ attempt=%@",target,d] url:web.URL];
                        }
                    }];
                });
            }

            for(NSNumber *d in @[@2,@5,@8]){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    typeof(self) self=weakSelf;if(!self)return;
                    NSString *verify=@"(function(){var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');var h=p?(p.getAttribute('href')||''):'';if(!h&&p&&p.closest){var a=p.closest('a[href]');h=a?(a.getAttribute('href')||''):'';}return {screenName:(h.charAt(0)==='/'&&h.indexOf('/',1)<0)?h.slice(1):'',href:h,location:location.href};})()";
                    [web evaluateJavaScript:verify completionHandler:^(id result,NSError *error){
                        if(error)return;
                        NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
                        NSString *screen=[dict[@"screenName"] isKindOfClass:NSString.class]?dict[@"screenName"]:@"";
                        NSString *href=[dict[@"href"] isKindOfClass:NSString.class]?dict[@"href"]:@"";
                        NSString *location=[dict[@"location"] isKindOfClass:NSString.class]?dict[@"location"]:@"";
                        [[DiagnosticsStore shared] addEvent:@"Account switch verify" detail:[NSString stringWithFormat:@"target=@%@ attempt=%@ current=@%@ href=%@ location=%@",target,d,screen,href,location] url:web.URL];
                        if([screen isEqualToString:target]){
                            [[DiagnosticsStore shared] addEvent:@"Account switch success" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];
                            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        } else if(d.integerValue==8){
                            NSString *event=screen.length?@"Account switch timeout":@"Account switch verification inconclusive";
                            [[DiagnosticsStore shared] addEvent:event detail:[NSString stringWithFormat:@"target=@%@ current=@%@",target,screen] url:web.URL];
                            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                            [web evaluateJavaScript:@"window.__scarletXNativeBypass=false" completionHandler:nil];
                        }
                    }];
                });
            }
        }];
    }];
}
@end
