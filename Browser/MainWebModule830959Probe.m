#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule830959ProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule830959ProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx830959Probe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 830959 probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module830959Probe)
@end

@implementation BrowserViewController (Module830959Probe)

static char SXModule830959ProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_830959_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_830959ProbeScript {
    return @"(function(){"
    "if(window.__scarletX830959ProbeDone)return;"
    "function around(src,needle,before,after){try{src=String(src||'');var p=src.indexOf(needle);if(p<0)return '';return src.slice(Math.max(0,p-(before||1200)),Math.min(src.length,p+(after||4200)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(typeof ex==='function')out=['<function>'];else if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,80);}catch(_){}return out;}"
    "function describe(v){var o={type:typeof v};try{if(typeof v==='function'){o.name=String(v.name||'');o.length=Number(v.length||0);o.source=String(v).slice(0,18000);}else if(v&&typeof v==='object'){o.keys=Object.keys(v).slice(0,120);}}catch(e){o.error=String(e);}return o;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m)return;var item={chunkGlobal:name,modules:[]};['830959','256599','631832','923187','302983'].forEach(function(mid){if(!req.m[mid])return;var src='';try{src=String(req.m[mid]||'');}catch(_){}var m={moduleId:mid,factoryLength:src.length,loaded:!!(req.c&&req.c[mid]),exportKeys:safeExports(req,mid),snippets:{}};m.snippets.api=around(src,'api:',2600,7600);m.snippets.featureSwitches=around(src,'featureSwitches',2600,7600);m.snippets.initialize=around(src,'initialize',2600,7600);m.snippets.withEndpoint=around(src,'withEndpoint',3600,10000);m.snippets.apiClient=around(src,'apiClient',3600,10000);m.snippets.extra=around(src,'extra',2200,6200);m.snippets.store=around(src,'store',2600,7600);if(mid==='631832'){m.factoryStart=src.slice(0,22000);m.snippets.edAssign=around(src,'ed=',7000,7000);m.snippets.edW=around(src,'ed.W',11000,7000);m.snippets.edWCall=around(src,'(0,ed.W)',11000,7000);}if(mid==='923187'){m.factoryStart=src.slice(0,30000);m.factoryEnd=src.slice(Math.max(0,src.length-22000));m.snippets.exportW=around(src,'W:',9000,14000);m.snippets.returnApi=around(src,'api:',9000,14000);m.snippets.createStore=around(src,'createStore',7000,12000);m.snippets.middleware=around(src,'middleware',7000,12000);try{var c=req.c&&req.c[mid],ex=c&&c.exports;if(ex&&typeof ex==='object'&&Object.prototype.hasOwnProperty.call(ex,'W'))m.runtimeW=describe(ex.W);}catch(e){m.runtimeError=String(e);}}if(mid==='302983'){m.factoryStart=src.slice(0,24000);m.factoryEnd=src.slice(Math.max(0,src.length-18000));m.snippets.JJ=around(src,'JJ',8000,12000);m.snippets.exportJJ=around(src,'JJ:',8000,12000);m.snippets.atom=around(src,'atom',7000,11000);m.snippets.createStore=around(src,'createStore',7000,11000);try{var c2=req.c&&req.c[mid],ex2=c2&&c2.exports;if(ex2&&typeof ex2==='object'&&Object.prototype.hasOwnProperty.call(ex2,'JJ'))m.runtimeJJ=describe(ex2.JJ);}catch(e){m.runtimeError=String(e);}}item.modules.push(m);});var ids=[];try{ids=Object.keys(req.m);}catch(_){}var referrers=[];for(var i=0;i<ids.length&&referrers.length<60;i++){var id=String(ids[i]),src='';try{src=String(req.m[id]||'');}catch(_){continue;}if(id==='256599')continue;var p=src.indexOf('256599');if(p<0)continue;referrers.push({moduleId:id,loaded:!!(req.c&&req.c[id]),exportKeys:safeExports(req,id),sourceLength:src.length,snippet:src.slice(Math.max(0,p-2200),Math.min(src.length,p+6200))});}item.referrers256599=referrers;var refs302983=[];var jjUsers=[];for(var j=0;j<ids.length;j++){var jid=String(ids[j]),jsrc='';try{jsrc=String(req.m[jid]||'');}catch(_){continue;}if(jid!=='302983'){var rp=jsrc.indexOf('302983');if(rp>=0&&refs302983.length<80)refs302983.push({moduleId:jid,loaded:!!(req.c&&req.c[jid]),exportKeys:safeExports(req,jid),sourceLength:jsrc.length,snippet:jsrc.slice(Math.max(0,rp-2600),Math.min(jsrc.length,rp+7600))});}var jp=jsrc.indexOf('.JJ');if(jp>=0&&jjUsers.length<80)jjUsers.push({moduleId:jid,loaded:!!(req.c&&req.c[jid]),exportKeys:safeExports(req,jid),sourceLength:jsrc.length,snippet:jsrc.slice(Math.max(0,jp-3600),Math.min(jsrc.length,jp+9000))});}item.referrers302983=refs302983;item.jjUsers=jjUsers;results.push(item);});"
    "if(!results.length)return;window.__scarletX830959ProbeDone=true;try{window.webkit.messageHandlers.scarletx830959Probe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_830959_viewDidLoad {
    [self sx_830959_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule830959ProbeHandler *handler = objc_getAssociatedObject(self, &SXModule830959ProbeHandlerKey);
    if (!handler) {
        handler = [SXModule830959ProbeHandler new];
        objc_setAssociatedObject(self, &SXModule830959ProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx830959Probe"];
    }

    NSString *script = [self sx_830959ProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
