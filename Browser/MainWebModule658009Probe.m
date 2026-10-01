#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXModule631832StoreUsageProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXModule631832StoreUsageProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletx631832StoreUsageProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web module 631832 store usage probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (Module631832StoreUsageProbe)
@end

@implementation BrowserViewController (Module631832StoreUsageProbe)

static char SXModule631832StoreUsageProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_631832StoreUsage_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_631832StoreUsageProbeScript {
    return @"(function(){"
    "if(window.__scarletX631832StoreUsageProbeDone)return;"
    "function around(src,index,before,after){try{src=String(src||'');index=Number(index||0);return src.slice(Math.max(0,index-(before||2500)),Math.min(src.length,index+(after||7000)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,120);}catch(_){}return out;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['631832'])return;var src='';try{src=String(req.m['631832']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'631832',factoryLength:src.length,loaded:!!(req.c&&req.c['631832']),exportKeys:safeExports(req,'631832'),factoryStart:src.slice(0,36000),factoryEnd:src.slice(Math.max(0,src.length-30000)),destructureMatches:[],storeUsages:[],snippets:{}};"
    "item.snippets.module923187=(()=>{var p=src.indexOf('923187');return p>=0?around(src,p,12000,18000):''})();"
    "item.snippets.jotaiStore=(()=>{var p=src.indexOf('jotaiStore');return p>=0?around(src,p,12000,18000):''})();"
    "item.snippets.Provider=(()=>{var p=src.indexOf('Provider');return p>=0?around(src,p,8000,12000):''})();"
    "item.snippets.storeProp=(()=>{var p=src.indexOf('store:');return p>=0?around(src,p,8000,12000):''})();"
    "var local='';try{var re=/jotaiStore\\s*:\\s*([A-Za-z_$][\\w$]*)/g,m;while((m=re.exec(src))&&item.destructureMatches.length<20){item.destructureMatches.push({local:m[1],index:m.index,snippet:around(src,m.index,5000,12000)});if(!local)local=m[1];}}catch(e){item.regexError=String(e);}item.jotaiStoreLocal=local;"
    "if(local){try{var escaped=local.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&');var useRe=new RegExp('(^|[^A-Za-z0-9_$])'+escaped+'([^A-Za-z0-9_$]|$)','g'),u;while((u=useRe.exec(src))&&item.storeUsages.length<40){var idx=u.index+(u[1]?u[1].length:0);item.storeUsages.push({index:idx,snippet:around(src,idx,4500,10000)});if(useRe.lastIndex===u.index)useRe.lastIndex++;}}catch(e){item.usageError=String(e);}}"
    "results.push(item);});"
    "if(!results.length)return;window.__scarletX631832StoreUsageProbeDone=true;try{window.webkit.messageHandlers.scarletx631832StoreUsageProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_631832StoreUsage_viewDidLoad {
    [self sx_631832StoreUsage_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXModule631832StoreUsageProbeHandler *handler = objc_getAssociatedObject(self, &SXModule631832StoreUsageProbeHandlerKey);
    if (!handler) {
        handler = [SXModule631832StoreUsageProbeHandler new];
        objc_setAssociatedObject(self, &SXModule631832StoreUsageProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletx631832StoreUsageProbe"];
    }

    NSString *script = [self sx_631832StoreUsageProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
