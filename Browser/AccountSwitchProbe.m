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
    [[DiagnosticsStore shared] addEvent:@"Account switch export probe start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *trace=[NSString stringWithFormat:
        @"(function(){var target='%@';"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-export '+JSON.stringify({kind:kind,target:target,href:location.href,data:data||{}})});}catch(_){}}"
         "function findModule(){var arr=window.webpackChunk_twitter_responsive_web;if(!Array.isArray(arr))return null;for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]],mo=ch[1],ks=Object.keys(mo);for(var j=0;j<ks.length;j++){var id=ks[j],f=mo[id],s='';try{s=Function.prototype.toString.call(f);}catch(_){}if(s.indexOf('account/multi/switch')>=0||s.indexOf('multi/switch')>=0){return {chunkIds:ids,moduleId:String(id),factory:f,source:s};}}}return null;}"
         "function captureRequire(){var arr=window.webpackChunk_twitter_responsive_web,req=null;if(!Array.isArray(arr))return null;try{arr.push([['sxprobe'+Date.now()+Math.random().toString(36).slice(2)],{},function(r){req=r;}]);}catch(_){}return req;}"
         "function requireIds(src){var out=[],seen={};var re=/\\b[a-zA-Z_$][\\w$]*\\((\\d{3,})\\)/g,m;while((m=re.exec(src))&&out.length<80){if(!seen[m[1]]){seen[m[1]]=1;out.push(m[1]);}}return out;}"
         "var hit=findModule(),req=captureRequire();if(!hit){send('module-missing',{});}else{var exp=null,keys=[],aInfo=null,xInfo=null;try{if(req)exp=req(hit.moduleId);}catch(e){send('require-error',{moduleId:hit.moduleId,error:String(e)});}try{if(exp&&((typeof exp==='object')||(typeof exp==='function')))keys=Object.keys(exp).slice(0,50);}catch(_){}"
         "try{var a=exp&&exp.A;if(typeof a==='function')aInfo={type:'function',name:a.name||'',length:a.length,source:Function.prototype.toString.call(a).slice(0,2500)};else aInfo={type:typeof a};}catch(e){aInfo={error:String(e)};}"
         "try{var x=exp&&exp.X;xInfo={type:typeof x,value:(typeof x==='string'?x.slice(0,500):null)};}catch(e){xInfo={error:String(e)};}"
         "send('module-detail',{moduleId:hit.moduleId,chunkIds:hit.chunkIds,exportKeys:keys,A:aInfo,X:xInfo,requireIds:requireIds(hit.source),factorySnippet:hit.source.slice(0,3500)});}"
         "return true;})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:trace completionHandler:^(__unused id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;
        if(error){[[DiagnosticsStore shared] addError:@"Account switch export probe failed" error:error url:web.URL];objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}

        NSString *open=@"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');if(!p)return false;window.__scarletXNativeBypass=true;p.click();return true;})()";
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
                    [web evaluateJavaScript:js completionHandler:^(id r2,NSError *e2){
                        typeof(self) self=weakSelf;if(!self)return;
                        objc_setAssociatedObject(self,&SXAttemptInFlightKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        if(e2)return;
                        NSDictionary *dict=[r2 isKindOfClass:NSDictionary.class]?r2:nil;
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
