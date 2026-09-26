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
         "window.__scarletXSwitchTraceTarget=target;window.__scarletXSwitchTraceStart=performance.now();"
         "function now(){return Math.round((performance.now()-(window.__scarletXSwitchTraceStart||performance.now()))*10)/10;}"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-transport '+JSON.stringify({kind:kind,target:window.__scarletXSwitchTraceTarget||'',tMs:now(),href:location.href,data:data||{}})});}catch(_){}}"
         "function interesting(u){return /account\\/multi\\/switch\\.json|viewer_context|flow\\/timeline|DelegatedAccountListQuery/i.test(String(u||''));}"
         "function sensitive(k){return /auth|token|csrf|cookie|ct0|authorization/i.test(String(k||''));}"
         "function cleanObj(v,depth){if(depth>4)return '[DEPTH]';if(v===null||v===undefined)return v;if(Array.isArray(v))return v.slice(0,40).map(function(x){return cleanObj(x,depth+1);});if(typeof v==='object'){var o={};Object.keys(v).slice(0,80).forEach(function(k){o[k]=sensitive(k)?'[REDACTED]':cleanObj(v[k],depth+1);});return o;}if(typeof v==='string')return v.slice(0,1200);if(typeof v==='number'||typeof v==='boolean')return v;return String(v).slice(0,1200);}"
         "function pairsBody(pairs,type){var o={};pairs.forEach(function(kv){var k=String(kv[0]||''),v=kv[1];o[k]=sensitive(k)?'[REDACTED]':String(v===undefined?'':v).slice(0,1200);});return {type:type,fields:o};}"
         "function bodySummary(b){try{if(b===undefined||b===null)return {type:'none'};if(typeof URLSearchParams!=='undefined'&&b instanceof URLSearchParams)return pairsBody(Array.from(b.entries()),'URLSearchParams');if(typeof FormData!=='undefined'&&b instanceof FormData)return pairsBody(Array.from(b.entries()).map(function(x){return [x[0],typeof x[1]==='string'?x[1]:'[BINARY]'];}),'FormData');if(typeof b==='string'){var s=b.slice(0,12000);try{return {type:'json',value:cleanObj(JSON.parse(s),0)};}catch(_){}if(s.indexOf('=')>=0){try{return pairsBody(Array.from(new URLSearchParams(s).entries()),'urlencoded');}catch(_){}}return {type:'string',length:b.length,preview:'[UNPARSED OMITTED]'};}return {type:(b&&b.constructor&&b.constructor.name)||typeof b};}catch(e){return {type:'error',error:String(e)};}}"
         "function contentType(h){try{return new Headers(h||{}).get('content-type')||'';}catch(_){return '';}}"
         "function safeText(text){var s=String(text||'').slice(0,12000);try{return cleanObj(JSON.parse(s),0);}catch(_){return s.slice(0,3000);}}"
         "if(!window.__scarletXSwitchTraceInstalled){window.__scarletXSwitchTraceInstalled=true;"
         "var op=history.pushState.bind(history);history.pushState=function(s,t,u){send('pushState',{url:String(u||'')});return op(s,t,u);};"
         "var orp=history.replaceState.bind(history);history.replaceState=function(s,t,u){send('replaceState',{url:String(u||'')});return orp(s,t,u);};"
         "var of=window.fetch;if(typeof of==='function'){window.fetch=function(input,init){var u='',m='GET',ct='',body=(init&&init.body);try{u=typeof input==='string'?input:(input&&input.url)||String(input||'');m=(init&&init.method)||(input&&input.method)||'GET';ct=contentType((init&&init.headers)||(input&&input.headers));}catch(_){}var watch=interesting(u);if(watch)send('fetch-request',{url:u,method:m,contentType:ct,body:bodySummary(body)});if(watch&&body===undefined&&typeof Request!=='undefined'&&input instanceof Request){try{input.clone().text().then(function(t){send('fetch-request-body',{url:u,body:bodySummary(t)});}).catch(function(){});}catch(_){}}var p=of.apply(this,arguments);return p.then(function(resp){if(watch){send('fetch-response',{url:u,status:resp.status,ok:resp.ok,contentType:resp.headers.get('content-type')||''});if(/account\\/multi\\/switch\\.json/i.test(u)){try{resp.clone().text().then(function(t){send('switch-response-body',{url:u,status:resp.status,body:safeText(t)});}).catch(function(){});}catch(_){}}}return resp;});};}"
         "var xo=XMLHttpRequest.prototype.open,xs=XMLHttpRequest.prototype.send,xh=XMLHttpRequest.prototype.setRequestHeader;"
         "XMLHttpRequest.prototype.open=function(m,u){this.__sxTrace={method:String(m||'GET'),url:String(u||''),contentType:''};return xo.apply(this,arguments);};"
         "XMLHttpRequest.prototype.setRequestHeader=function(k,v){try{if(this.__sxTrace&&String(k||'').toLowerCase()==='content-type')this.__sxTrace.contentType=String(v||'');}catch(_){}return xh.apply(this,arguments);};"
         "XMLHttpRequest.prototype.send=function(body){var self=this,meta=this.__sxTrace||{method:'GET',url:'',contentType:''},watch=interesting(meta.url);if(watch)send('xhr-request',{url:meta.url,method:meta.method,contentType:meta.contentType||'',body:bodySummary(body)});if(watch){this.addEventListener('loadend',function(){var d={url:meta.url,status:self.status,contentType:self.getResponseHeader('content-type')||''};send('xhr-response',d);if(/account\\/multi\\/switch\\.json/i.test(meta.url)){var txt='';try{if(!self.responseType||self.responseType==='text')txt=self.responseText||'';}catch(_){}send('switch-response-body',{url:meta.url,status:self.status,body:safeText(txt)});}}, {once:true});}return xs.apply(this,arguments);};"
         "addEventListener('popstate',function(){send('popstate',{});});addEventListener('hashchange',function(){send('hashchange',{});});addEventListener('pagehide',function(){send('pagehide',{});});addEventListener('beforeunload',function(){send('beforeunload',{});});"
         "}"
         "send('trace-start',{version:2});return true;})()",escaped];

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
