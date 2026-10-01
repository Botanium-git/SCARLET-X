#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule658009KqProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule658009KqProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx658009KqProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 658009 Kq probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module658009KqProbe)
@end

@implementation BrowserViewController (Module658009KqProbe)

static char SXModule658009KqProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_658009Kq_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_658009KqProbeScript {
    return @"(function(){"
    "if(window.__scarletX658009KqProbeDone)return;"
    "function around(src,index,before,after){try{src=String(src||'');index=Number(index||0);return src.slice(Math.max(0,index-(before||3500)),Math.min(src.length,index+(after||9000)));}catch(_){return '';}}"
    "function describe(v){var o={type:typeof v};try{o.tag=Object.prototype.toString.call(v);o.keys=v?Reflect.ownKeys(v).map(String).slice(0,120):[];if(typeof v==='function'){o.name=String(v.name||'');o.length=Number(v.length||0);o.source=String(v).slice(0,24000);}['Provider','Consumer','_context','_currentValue','_currentValue2','$$typeof'].forEach(function(k){try{if(v&&k in v){var x=v[k];o[k]={type:typeof x,tag:Object.prototype.toString.call(x),keys:x?Reflect.ownKeys(x).map(String).slice(0,60):[]};if(typeof x==='function')o[k].source=String(x).slice(0,8000);}}catch(_){}});}catch(e){o.error=String(e);}return o;}"
    "function descriptor(obj,key){try{var d=Object.getOwnPropertyDescriptor(obj,key);if(!d)return null;return{configurable:!!d.configurable,enumerable:!!d.enumerable,writable:'writable'in d?!!d.writable:null,hasGet:typeof d.get==='function',hasSet:typeof d.set==='function',valueType:'value'in d?typeof d.value:null};}catch(e){return{error:String(e)}}}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['658009'])return;var src='';try{src=String(req.m['658009']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'658009',factoryLength:src.length,loaded:!!(req.c&&req.c['658009']),factoryStart:src.slice(0,36000),factoryEnd:src.slice(Math.max(0,src.length-30000)),snippets:{},runtime:{}};function sn(k,n,b,a){var p=src.indexOf(n);item.snippets[k]=p>=0?around(src,p,b,a):'';}sn('createContext','createContext',12000,18000);sn('Kq','Kq',12000,18000);sn('exportKq','Kq:',12000,18000);sn('395745','395745',12000,18000);sn('Pj','Pj',10000,15000);sn('md','md',10000,15000);sn('storeProp','store:',10000,15000);sn('Provider','Provider',10000,15000);try{var c=req.c&&req.c['658009'],ex=c&&c.exports;item.runtime.exportKeys=ex&&typeof ex==='object'?Object.keys(ex).slice(0,120):[];if(ex&&typeof ex==='object'){['Kq','Pj','md'].forEach(function(k){if(Object.prototype.hasOwnProperty.call(ex,k)){item.runtime[k]=describe(ex[k]);item.runtime[k+'Descriptor']=descriptor(ex,k);}});}}catch(e){item.runtime.error=String(e);}results.push(item);});"
    "window.__scarletX658009KqProbeDone=true;try{window.webkit.messageHandlers.scarletx658009KqProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_658009Kq_viewDidLoad {
    [self sx_658009Kq_viewDidLoad];
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;
    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;
    SXModule658009KqProbeHandler *handler = objc_getAssociatedObject(self, &SXModule658009KqProbeHandlerKey);
    if (!handler) {
        handler = [SXModule658009KqProbeHandler new];
        objc_setAssociatedObject(self, &SXModule658009KqProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx658009KqProbe"];
    }
    NSString *script = [self sx_658009KqProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
