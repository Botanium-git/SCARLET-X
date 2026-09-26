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
    [[DiagnosticsStore shared] addEvent:@"Account switch factory probe start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *trace=[NSString stringWithFormat:
        @"(function(){var target='%@';"
         "window.__scarletXSwitchTraceTarget=target;window.__scarletXSwitchTraceStart=performance.now();"
         "function now(){return Math.round((performance.now()-(window.__scarletXSwitchTraceStart||performance.now()))*10)/10;}"
         "function stack(){try{return String((new Error()).stack||'').slice(0,12000);}catch(_){return '';}}"
         "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-factory '+JSON.stringify({kind:kind,target:window.__scarletXSwitchTraceTarget||'',tMs:now(),href:location.href,data:data||{}})});}catch(_){}}"
         "function isSwitch(u){return /account\\/multi\\/switch\\.json/i.test(String(u||''));}"
         "function sensitive(k){return /auth|token|csrf|cookie|ct0|authorization/i.test(String(k||''));}"
         "function headerValue(k,v){var s=String(v===undefined?'':v);return sensitive(k)?{present:s.length>0,length:s.length}:{value:s.slice(0,500),length:s.length};}"
         "function summarizeHeaders(h){var o={};try{new Headers(h||{}).forEach(function(v,k){o[k]=headerValue(k,v);});}catch(_){}return o;}"
         "function scanWebpack(){var arr=window.webpackChunk_twitter_responsive_web;var hits=[];var chunks=0,mods=0;if(!Array.isArray(arr))return {present:false};for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;chunks++;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]];var mo=ch[1],ks=Object.keys(mo);mods+=ks.length;for(var j=0;j<ks.length;j++){var id=ks[j],f=mo[id],s='';try{s=Function.prototype.toString.call(f);}catch(_){}if(!s)continue;var terms=['account/multi/switch','multi/switch','switch.json'];for(var t=0;t<terms.length;t++){var p=s.indexOf(terms[t]);if(p>=0){hits.push({chunkIds:ids,moduleId:id,term:terms[t],snippet:s.slice(Math.max(0,p-350),Math.min(s.length,p+650))});break;}}if(hits.length>=20)break;}if(hits.length>=20)break;}return {present:true,arrayLength:arr.length,chunksScanned:chunks,modulesScanned:mods,hits:hits};}"
         "function captureRequire(){var arr=window.webpackChunk_twitter_responsive_web;if(!Array.isArray(arr))return {ok:false,reason:'no-array'};var req=null;var marker='sx'+Date.now()+Math.random().toString(36).slice(2);try{arr.push([[marker],{},function(r){req=r;}]);}catch(e){return {ok:false,reason:'push-error',error:String(e)};}if(!req)return {ok:false,reason:'no-require'};window.__scarletXWebpackRequire=req;return {ok:true,type:typeof req,hasM:!!req.m,hasC:!!req.c,moduleCount:req.m?Object.keys(req.m).length:null,cacheCount:req.c?Object.keys(req.c).length:null};}"
         "function inspectHits(hits){var req=window.__scarletXWebpackRequire;if(!req||!req.c)return [];var out=[];for(var i=0;i<hits.length;i++){var id=String(hits[i].moduleId),m=req.c[id];if(!m)continue;var ex=m.exports,row={moduleId:id,cached:true,exportsType:typeof ex,keys:[]};try{if(ex&&((typeof ex==='object')||(typeof ex==='function'))){row.keys=Object.keys(ex).slice(0,40).map(function(k){var v;try{v=ex[k];}catch(_){return {key:k,type:'error'};}return {key:k,type:typeof v,name:(typeof v==='function'&&v.name)?v.name:''};});}}catch(_){}out.push(row);}return out;}"
         "var scan=scanWebpack();var cap=captureRequire();send('webpack-scan',{scan:scan,require:cap,exports:scan.hits?inspectHits(scan.hits):[]});"
         "if(!window.__scarletXSwitchFactoryProbeInstalled){window.__scarletXSwitchFactoryProbeInstalled=true;var of=window.fetch;if(typeof of==='function'){window.fetch=function(input,init){var u='',m='GET',hs={};try{u=typeof input==='string'?input:(input&&input.url)||String(input||'');m=(init&&init.method)||(input&&input.method)||'GET';hs=summarizeHeaders((init&&init.headers)||(input&&input.headers));}catch(_){}if(isSwitch(u))send('fetch-request',{url:u,method:m,headers:hs,stack:stack()});var p=of.apply(this,arguments);return p.then(function(resp){if(isSwitch(u))send('fetch-response',{url:u,status:resp.status,ok:resp.ok});return resp;});};}var xo=XMLHttpRequest.prototype.open,xs=XMLHttpRequest.prototype.send,xh=XMLHttpRequest.prototype.setRequestHeader;XMLHttpRequest.prototype.open=function(m,u){this.__sxFactoryTrace={method:String(m||'GET'),url:String(u||''),headers:{},openStack:isSwitch(u)?stack():''};return xo.apply(this,arguments);};XMLHttpRequest.prototype.setRequestHeader=function(k,v){try{if(this.__sxFactoryTrace&&isSwitch(this.__sxFactoryTrace.url))this.__sxFactoryTrace.headers[String(k||'').toLowerCase()]=headerValue(k,v);}catch(_){}return xh.apply(this,arguments);};XMLHttpRequest.prototype.send=function(body){var self=this,meta=this.__sxFactoryTrace||{method:'GET',url:'',headers:{},openStack:''};if(isSwitch(meta.url))send('xhr-request',{url:meta.url,method:meta.method,headers:meta.headers,openStack:meta.openStack,sendStack:stack()});if(isSwitch(meta.url)){this.addEventListener('loadend',function(){send('xhr-response',{url:meta.url,status:self.status});},{once:true});}return xs.apply(this,arguments);};}send('probe-installed',{version:5});return true;})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:trace completionHandler:^(__unused id r,NSError *traceError){
        typeof(self) self=weakSelf;if(!self)return;
        if(traceError){[[DiagnosticsStore shared] addError:@"Account switch factory probe failed" error:traceError url:web.URL];objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}
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
                    [web evaluateJavaScript:js completionHandler:^(id result,NSError *error){
                        typeof(self) self=weakSelf;if(!self)return;
                        objc_setAssociatedObject(self,&SXAttemptInFlightKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        if(error)return;
                        NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
                        if([dict[@"found"] boolValue]){objc_setAssociatedObject(self,&SXClickIssuedKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[[DiagnosticsStore shared] addEvent:@"Account switch button clicked" detail:[NSString stringWithFormat:@"target=@%@ attempt=%@",target,d] url:web.URL];}
                    }];
                });
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(8.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{typeof(self) self=weakSelf;if(!self)return;objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[web evaluateJavaScript:@"window.__scarletXNativeBypass=false" completionHandler:nil];});
        }];
    }];
}
@end
