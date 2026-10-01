#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule658009ProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule658009ProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx658009Probe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 658009 probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module658009Probe)
@end

@implementation BrowserViewController (Module658009Probe)

static char SXModule658009ProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_658009_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_658009ProbeScript {
    return @"(function(){"
    "if(window.__scarletX658009ProbeDone)return;"
    "function around(src,needle,before,after){try{src=String(src||'');var p=src.indexOf(needle);if(p<0)return '';return src.slice(Math.max(0,p-(before||1500)),Math.min(src.length,p+(after||5000)));}catch(_){return '';}}"
    "function describe(v){var o={type:typeof v};try{if(typeof v==='function'){o.name=String(v.name||'');o.length=Number(v.length||0);o.source=String(v).slice(0,18000);}else if(v&&typeof v==='object'){o.keys=Object.keys(v).slice(0,120);}}catch(e){o.error=String(e);}return o;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['658009'])return;var src='';try{src=String(req.m['658009']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'658009',factoryLength:src.length,loaded:!!(req.c&&req.c['658009']),factoryStart:src.slice(0,26000),factoryEnd:src.slice(Math.max(0,src.length-18000)),snippets:{}};item.snippets.md=around(src,'md',9000,14000);item.snippets.exportMd=around(src,'md:',9000,14000);item.snippets.atom=around(src,'atom',7000,11000);item.snippets.useAtom=around(src,'useAtom',7000,11000);item.snippets.useStore=around(src,'useStore',7000,11000);item.snippets.Provider=around(src,'Provider',7000,11000);try{var c=req.c&&req.c['658009'],ex=c&&c.exports;item.exportKeys=ex&&typeof ex==='object'?Object.keys(ex).slice(0,120):[];if(ex&&typeof ex==='object'&&Object.prototype.hasOwnProperty.call(ex,'md'))item.runtimeMd=describe(ex.md);}catch(e){item.runtimeError=String(e);}results.push(item);});"
    "if(!results.length)return;window.__scarletX658009ProbeDone=true;try{window.webkit.messageHandlers.scarletx658009Probe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_658009_viewDidLoad {
    [self sx_658009_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule658009ProbeHandler *handler = objc_getAssociatedObject(self, &SXModule658009ProbeHandlerKey);
    if (!handler) {
        handler = [SXModule658009ProbeHandler new];
        objc_setAssociatedObject(self, &SXModule658009ProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx658009Probe"];
    }

    NSString *script = [self sx_658009ProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
