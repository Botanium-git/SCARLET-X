#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule923187StoreProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule923187StoreProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx923187StoreProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 923187 store probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module923187StoreProbe)
@end

@implementation BrowserViewController (Module923187StoreProbe)

static char SXModule923187StoreProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_923187Store_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_923187StoreProbeScript {
    return @"(function(){"
    "if(window.__scarletX923187StoreProbeDone)return;"
    "function around(src,needle,before,after){try{src=String(src||'');var p=src.indexOf(needle);if(p<0)return '';return src.slice(Math.max(0,p-(before||2000)),Math.min(src.length,p+(after||7000)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,120);}catch(_){}return out;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['923187'])return;var src='';try{src=String(req.m['923187']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'923187',factoryLength:src.length,loaded:!!(req.c&&req.c['923187']),exportKeys:safeExports(req,'923187'),factoryStart:src.slice(0,34000),factoryEnd:src.slice(Math.max(0,src.length-26000)),snippets:{}};item.snippets.import395745=around(src,'395745',12000,18000);item.snippets.yDollar=around(src,'.y$',12000,18000);item.snippets.zp=around(src,'.zp',12000,18000);item.snippets.jotaiStore=around(src,'jotaiStore',12000,18000);item.snippets.cSet=around(src,'.set(',12000,18000);item.snippets.jj=around(src,'.JJ',12000,18000);item.snippets.returnApi=around(src,'api:',12000,18000);item.snippets.createStore=around(src,'createStore',12000,18000);var matches=[];try{var re=/([A-Za-z_$][\\w$]*)=r\\(395745\\)/g,m;while((m=re.exec(src))&&matches.length<20)matches.push({alias:m[1],index:m.index,snippet:src.slice(Math.max(0,m.index-4000),Math.min(src.length,m.index+12000))});}catch(_){}item.import395745Matches=matches;results.push(item);});"
    "if(!results.length)return;window.__scarletX923187StoreProbeDone=true;try{window.webkit.messageHandlers.scarletx923187StoreProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_923187Store_viewDidLoad {
    [self sx_923187Store_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule923187StoreProbeHandler *handler = objc_getAssociatedObject(self, &SXModule923187StoreProbeHandlerKey);
    if (!handler) {
        handler = [SXModule923187StoreProbeHandler new];
        objc_setAssociatedObject(self, &SXModule923187StoreProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx923187StoreProbe"];
    }

    NSString *script = [self sx_923187StoreProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
