#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXAppRegistrationBroadProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXAppRegistrationBroadProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletxAppRegistrationBroadProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web App registration broad probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (AppRegistrationBroadProbe)
@end

@implementation BrowserViewController (AppRegistrationBroadProbe)

static char SXAppRegistrationBroadProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_appRegistrationBroad_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_appRegistrationBroadProbeScript {
    return @"(function(){"
    "if(window.__scarletXAppRegistrationBroadProbeDone)return;"
    "function around(src,index,before,after){try{src=String(src||'');index=Number(index||0);return src.slice(Math.max(0,index-(before||2200)),Math.min(src.length,index+(after||7000)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,120);}catch(_){}return out;}"
    "function summarize(req,id,src){src=String(src||'');var item={moduleId:String(id),factoryLength:src.length,loaded:!!(req.c&&req.c[id]),exportKeys:safeExports(req,String(id)),hits:{}};var needles={module989295:'989295',registerComponent:'registerComponent',registerConfig:'registerConfig',registerRunnable:'registerRunnable',runApplication:'runApplication',appDouble:'\"App\"',appSingle:\"'App'\",jotaiStore:'jotaiStore',provider:'Provider',storeProp:'store:'};Object.keys(needles).forEach(function(k){var p=src.indexOf(needles[k]);if(p>=0)item.hits[k]={index:p,snippet:around(src,p,6500,12000)};});item.factoryStart=src.slice(0,18000);item.factoryEnd=src.slice(Math.max(0,src.length-14000));return item;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m)return;var root={chunkGlobal:name,scannedCount:Object.keys(req.m).length,module989295Referrers:[],registrationKeywordModules:[],appLiteralModules:[]};"
    "try{Object.keys(req.m).forEach(function(mid){var src='';try{src=String(req.m[mid]||'');}catch(_){}if(!src)return;var has989=src.indexOf('989295')>=0;var hasReg=src.indexOf('registerComponent')>=0||src.indexOf('registerConfig')>=0||src.indexOf('registerRunnable')>=0;var hasApp=src.indexOf('\"App\"')>=0||src.indexOf(\"'App'\")>=0;if(has989&&root.module989295Referrers.length<50)root.module989295Referrers.push(summarize(req,mid,src));if(hasReg&&root.registrationKeywordModules.length<50)root.registrationKeywordModules.push(summarize(req,mid,src));if(hasApp&&(has989||hasReg||src.indexOf('runApplication')>=0)&&root.appLiteralModules.length<50)root.appLiteralModules.push(summarize(req,mid,src));});}catch(e){root.scanError=String(e);}results.push(root);});"
    "window.__scarletXAppRegistrationBroadProbeDone=true;try{window.webkit.messageHandlers.scarletxAppRegistrationBroadProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_appRegistrationBroad_viewDidLoad {
    [self sx_appRegistrationBroad_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXAppRegistrationBroadProbeHandler *handler = objc_getAssociatedObject(self, &SXAppRegistrationBroadProbeHandlerKey);
    if (!handler) {
        handler = [SXAppRegistrationBroadProbeHandler new];
        objc_setAssociatedObject(self, &SXAppRegistrationBroadProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxAppRegistrationBroadProbe"];
    }

    NSString *script = [self sx_appRegistrationBroadProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
