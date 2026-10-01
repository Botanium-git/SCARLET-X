#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule658009SimpleProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule658009SimpleProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx658009SimpleProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 658009 simple probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module658009SimpleProbe)
@end

@implementation BrowserViewController (Module658009SimpleProbe)

static char SXModule658009SimpleProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_658009Simple_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_658009SimpleProbeScript {
    return @"(function(){"
    "if(window.__scarletX658009SimpleProbeDone)return;"
    "var payload={pagePath:String(location.pathname||''),found:false,results:[],errors:[]};"
    "try{"
      "var globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);"
      "globals.forEach(function(name,gi){"
        "var req=null;"
        "try{var marker=930000000+Math.floor(Math.random()*60000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){payload.errors.push('capture:'+String(e));}"
        "if(!req||!req.m||!req.m['658009'])return;"
        "payload.found=true;"
        "var src='';try{src=String(req.m['658009']||'');}catch(e){payload.errors.push('factory:'+String(e));}"
        "var item={chunkGlobal:name,moduleId:'658009',factoryLength:src.length,factoryStart:src.slice(0,42000),factoryEnd:src.slice(Math.max(0,src.length-32000)),runtime:{}};"
        "try{var c=req.c&&req.c['658009'],ex=c&&c.exports;if(ex&&typeof ex==='object'){item.runtime.exportKeys=Object.keys(ex).slice(0,120);['Kq','Pj','md'].forEach(function(k){try{var v=ex[k];item.runtime[k]={type:typeof v,name:typeof v==='function'?String(v.name||''):'',length:typeof v==='function'?Number(v.length||0):null,source:typeof v==='function'?String(v).slice(0,28000):''};}catch(e){item.runtime[k]={error:String(e)};}});}}catch(e){item.runtime.error=String(e);}"
        "payload.results.push(item);"
      "});"
    "}catch(e){payload.errors.push('top:'+String(e));}"
    "window.__scarletX658009SimpleProbeDone=true;"
    "try{window.webkit.messageHandlers.scarletx658009SimpleProbe.postMessage(payload);}catch(e){}"
    "})();";
}

- (void)sx_658009Simple_viewDidLoad {
    [self sx_658009Simple_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule658009SimpleProbeHandler *handler = objc_getAssociatedObject(self, &SXModule658009SimpleProbeHandlerKey);
    if (!handler) {
        handler = [SXModule658009SimpleProbeHandler new];
        objc_setAssociatedObject(self, &SXModule658009SimpleProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx658009SimpleProbe"];
    }

    NSString *script = [self sx_658009SimpleProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (!strongWebView) return;
            [strongWebView evaluateJavaScript:script completionHandler:^(__unused id result, NSError *error) {
                if (error) {
                    [[DiagnosticsStore shared] addEvent:@"Main Web module 658009 probe JS error"
                                                detail:error.localizedDescription ?: @"unknown JavaScript error"
                                                   url:nil];
                }
            }];
        });
    }
}

@end
