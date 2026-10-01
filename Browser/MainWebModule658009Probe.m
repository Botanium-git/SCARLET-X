#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule395745ProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule395745ProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx395745Probe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 395745 probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module395745Probe)
@end

@implementation BrowserViewController (Module395745Probe)

static char SXModule395745ProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_395745_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_395745ProbeScript {
    return @"(function(){"
    "if(window.__scarletX395745ProbeDone)return;"
    "function around(src,needle,before,after){try{src=String(src||'');var p=src.indexOf(needle);if(p<0)return '';return src.slice(Math.max(0,p-(before||1500)),Math.min(src.length,p+(after||5000)));}catch(_){return '';}}"
    "function describe(v){var o={type:typeof v};try{if(typeof v==='function'){o.name=String(v.name||'');o.length=Number(v.length||0);o.source=String(v).slice(0,18000);}else if(v&&typeof v==='object'){o.keys=Object.keys(v).slice(0,120);}}catch(e){o.error=String(e);}return o;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['395745'])return;var src='';try{src=String(req.m['395745']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'395745',factoryLength:src.length,loaded:!!(req.c&&req.c['395745']),factoryStart:src.slice(0,26000),factoryEnd:src.slice(Math.max(0,src.length-18000)),snippets:{}};item.snippets.zp=around(src,'zp',9000,14000);item.snippets.exportZp=around(src,'zp:',9000,14000);item.snippets.yDollar=around(src,'y$',9000,14000);item.snippets.exportYDollar=around(src,'y$:',9000,14000);item.snippets.get=around(src,'.get',7000,11000);item.snippets.set=around(src,'.set',7000,11000);item.snippets.sub=around(src,'.sub',7000,11000);item.snippets.defaultStore=around(src,'default',7000,11000);try{var c=req.c&&req.c['395745'],ex=c&&c.exports;item.exportKeys=ex&&typeof ex==='object'?Object.keys(ex).slice(0,120):[];if(ex&&typeof ex==='object'&&Object.prototype.hasOwnProperty.call(ex,'zp'))item.runtimeZp=describe(ex.zp);if(ex&&typeof ex==='object'&&Object.prototype.hasOwnProperty.call(ex,'y$'))item.runtimeYDollar=describe(ex['y$']);}catch(e){item.runtimeError=String(e);}results.push(item);});"
    "if(!results.length)return;window.__scarletX395745ProbeDone=true;try{window.webkit.messageHandlers.scarletx395745Probe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_395745_viewDidLoad {
    [self sx_395745_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule395745ProbeHandler *handler = objc_getAssociatedObject(self, &SXModule395745ProbeHandlerKey);
    if (!handler) {
        handler = [SXModule395745ProbeHandler new];
        objc_setAssociatedObject(self, &SXModule395745ProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx395745Probe"];
    }

    NSString *script = [self sx_395745ProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
