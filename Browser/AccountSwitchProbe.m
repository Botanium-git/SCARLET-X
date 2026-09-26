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
    [[DiagnosticsStore shared] addEvent:@"Account switch header probe start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *trace=[NSString stringWithFormat:
        @"(function(){var target='%@';"
         "window.__scarletXSwitchTraceTarget=target;window.__scarletXSwitchTraceStart=performance.now();"
         "function now(){return Math.round((performance.now()-(window.__scarletXSwitchTraceStart||performance.now()))*10)/10;}"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-header '+JSON.stringify({kind:kind,target:window.__scarletXSwitchTraceTarget||'',tMs:now(),href:location.href,data:data||{}})});}catch(_){}}"
         "function isSwitch(u){return /account\\/multi\\/switch\\.json/i.test(String(u||''));}"
         "function sensitive(k){return /auth|token|csrf|cookie|ct0|authorization/i.test(String(k||''));}"
         "function headerValue(k,v){var s=String(v===undefined?'':v);return sensitive(k)?{present:s.length>0,length:s.length}:{value:s.slice(0,500),length:s.length};}"
         "function summarizeHeaders(h){var o={};try{new Headers(h||{}).forEach(function(v,k){o[k]=headerValue(k,v);});}catch(_){}return o;}"
         "if(!window.__scarletXSwitchHeaderProbeInstalled){window.__scarletXSwitchHeaderProbeInstalled=true;"
         "var of=window.fetch;if(typeof of==='function'){window.fetch=function(input,init){var u='',m='GET',hs={};try{u=typeof input==='string'?input:(input&&input.url)||String(input||'');m=(init&&init.method)||(input&&input.method)||'GET';hs=summarizeHeaders((init&&init.headers)||(input&&input.headers));}catch(_){}if(isSwitch(u))send('fetch-request',{url:u,method:m,headers:hs});var p=of.apply(this,arguments);return p.then(function(resp){if(isSwitch(u))send('fetch-response',{url:u,status:resp.status,ok:resp.ok});return resp;});};}"
         "var xo=XMLHttpRequest.prototype.open,xs=XMLHttpRequest.prototype.send,xh=XMLHttpRequest.prototype.setRequestHeader;"
         "XMLHttpRequest.prototype.open=function(m,u){this.__sxHeaderTrace={method:String(m||'GET'),url:String(u||''),headers:{}};return xo.apply(this,arguments);};"
         "XMLHttpRequest.prototype.setRequestHeader=function(k,v){try{if(this.__sxHeaderTrace&&isSwitch(this.__sxHeaderTrace.url))this.__sxHeaderTrace.headers[String(k||'').toLowerCase()]=headerValue(k,v);}catch(_){}return xh.apply(this,arguments);};"
         "XMLHttpRequest.prototype.send=function(body){var self=this,meta=this.__sxHeaderTrace||{method:'GET',url:'',headers:{}};if(isSwitch(meta.url))send('xhr-request',{url:meta.url,method:meta.method,headers:meta.headers});if(isSwitch(meta.url)){this.addEventListener('loadend',function(){send('xhr-response',{url:meta.url,status:self.status});},{once:true});}return xs.apply(this,arguments);};"
         "}"
         "send('probe-installed',{});return true;})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:trace completionHandler:^(__unused id r,NSError *traceError){
        typeof(self) self=weakSelf;if(!self)return;
        if(traceError){[[DiagnosticsStore shared] addError:@"Account switch header probe failed" error:traceError url:web.URL];objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}

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

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(8.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                typeof(self) self=weakSelf;if(!self)return;
                objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [web evaluateJavaScript:@"window.__scarletXNativeBypass=false" completionHandler:nil];
            });
        }];
    }];
}
@end
