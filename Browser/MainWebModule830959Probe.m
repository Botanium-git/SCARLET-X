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
        Method original = class_getInstanceMethod(self, @selector(viewDidAppear:));
        Method replacement = class_getInstanceMethod(self, @selector(sx_830959_viewDidAppear:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_830959ProbeScript {
    return @"(function(){"
    "if(window.__scarletX830959ProbeDone)return;"
    "function around(src,needle,before,after){try{src=String(src||'');var p=src.indexOf(needle);if(p<0)return '';return src.slice(Math.max(0,p-(before||1200)),Math.min(src.length,p+(after||4200)));}catch(_){return '';}}"
    "function describe(v){var o={type:typeof v};try{if(typeof v==='function'){o.name=String(v.name||'');o.length=Number(v.length||0);o.source=String(v).slice(0,12000);}else if(v&&typeof v==='object'){o.keys=Object.getOwnPropertyNames(v).slice(0,120);var p=Object.getPrototypeOf(v);o.constructorName=String(v.constructor&&v.constructor.name||'');o.prototypeKeys=p?Object.getOwnPropertyNames(p).slice(0,120):[];}}catch(e){o.error=String(e);}return o;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['830959'])return;var src='';try{src=String(req.m['830959']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'830959',factoryLength:src.length,loaded:!!(req.c&&req.c['830959']),exportKeys:[],snippets:{}};item.snippets.getEndpoint=around(src,'getEndpoint',2200,7000);item.snippets.network=around(src,'network',2200,7000);item.snippets.extra=around(src,'extra',1800,5200);item.snippets.api=around(src,'api',1800,5200);item.snippets.dispatch=around(src,'dispatch',1800,5200);item.snippets.getState=around(src,'getState',1800,5200);try{var c=req.c&&req.c['830959'];if(c){var ex=c.exports;item.exportKeys=ex&&typeof ex==='object'?Object.keys(ex).slice(0,120):(typeof ex==='function'?['<function>']:[]);if(ex&&typeof ex==='object'){item.exports={};Object.keys(ex).slice(0,30).forEach(function(k){item.exports[k]=describe(ex[k]);});}else if(typeof ex==='function'){item.moduleExport=describe(ex);}}}catch(e){item.runtimeError=String(e);}results.push(item);});"
    "if(!results.length)return;window.__scarletX830959ProbeDone=true;try{window.webkit.messageHandlers.scarletx830959Probe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_830959_viewDidAppear:(BOOL)animated {
    [self sx_830959_viewDidAppear:animated];

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
    for (NSNumber *delay in @[@0.5, @1.5, @3.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
