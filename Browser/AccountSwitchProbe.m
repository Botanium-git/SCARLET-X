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
    [[DiagnosticsStore shared] addEvent:@"Account switch caller probe start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *trace=[NSString stringWithFormat:
        @"(function(){var target='%@';"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-caller '+JSON.stringify({kind:kind,target:target,href:location.href,data:data||{}})});}catch(_){}}"
         "function findSwitchModule(){var arr=window.webpackChunk_twitter_responsive_web;if(!Array.isArray(arr))return null;for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]],mo=ch[1],ks=Object.keys(mo);for(var j=0;j<ks.length;j++){var id=ks[j],f=mo[id],s='';try{s=Function.prototype.toString.call(f);}catch(_){}if(s.indexOf('account/multi/switch')>=0||s.indexOf('multi/switch')>=0)return {chunkIds:ids,moduleId:String(id),source:s};}}return null;}"
         "function findCallers(targetId){var arr=window.webpackChunk_twitter_responsive_web;if(!Array.isArray(arr))return [];var out=[];var pats=[new RegExp('\\\\('+targetId+'\\\\)'),new RegExp('require\\\\('+targetId+'\\\\)'),new RegExp('[=,:]'+targetId+'(?:[^0-9]|$)')];for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]],mo=ch[1],ks=Object.keys(mo);for(var j=0;j<ks.length;j++){var id=String(ks[j]);if(id===String(targetId))continue;var s='';try{s=Function.prototype.toString.call(mo[id]);}catch(_){}if(!s)continue;var hit=-1;for(var p=0;p<pats.length;p++){var m=s.match(pats[p]);if(m){hit=m.index;break;}}if(hit<0)continue;var start=Math.max(0,hit-1200),end=Math.min(s.length,hit+2200);var sn=s.slice(start,end);var signals={apiClient:sn.indexOf('apiClient')>=0,featureSwitches:sn.indexOf('featureSwitches')>=0,switchWord:sn.indexOf('.switch')>=0,multiAccount:sn.indexOf('multiAccount')>=0};out.push({chunkIds:ids,moduleId:id,hitOffset:hit,signals:signals,snippet:sn});if(out.length>=40)return out;}}return out;}"
         "var sw=findSwitchModule();if(!sw){send('switch-module-missing',{});return true;}var callers=findCallers(sw.moduleId);send('caller-scan',{switchModuleId:sw.moduleId,switchChunkIds:sw.chunkIds,callerCount:callers.length,callers:callers});return true;})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:trace completionHandler:^(__unused id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;
        if(error){[[DiagnosticsStore shared] addError:@"Account switch caller probe failed" error:error url:web.URL];objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}

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
