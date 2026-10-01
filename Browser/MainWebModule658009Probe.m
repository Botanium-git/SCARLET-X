#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXAppRootJotaiProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXAppRootJotaiProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletxAppRootJotaiProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web App root Jotai probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (AppRootJotaiProbe)
@end

@implementation BrowserViewController (AppRootJotaiProbe)

static char SXAppRootJotaiProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_appRootJotai_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_appRootJotaiProbeScript {
    return @"(function(){"
    "if(window.__scarletXAppRootJotaiProbeDone)return;"
    "function around(src,index,before,after){try{src=String(src||'');index=Number(index||0);return src.slice(Math.max(0,index-(before||2500)),Math.min(src.length,index+(after||7000)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,120);}catch(_){}return out;}"
    "function moduleItem(req,id){var src='';try{src=String(req.m[id]||'');}catch(_){}var item={moduleId:String(id),factoryLength:src.length,loaded:!!(req.c&&req.c[id]),exportKeys:safeExports(req,String(id)),factoryStart:src.slice(0,32000),factoryEnd:src.slice(Math.max(0,src.length-26000)),snippets:{}};function sn(key,needle,b,a){var p=src.indexOf(needle);item.snippets[key]=p>=0?around(src,p,b,a):'';}sn('jotaiStore','jotaiStore',10000,16000);sn('initialProps','initialProps',10000,16000);sn('Provider','Provider',10000,16000);sn('storeProp','store:',10000,16000);sn('runApplication','runApplication',10000,16000);sn('createElement','createElement',8000,12000);sn('jsx','.jsx',8000,12000);return item;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m||!req.m['631832'])return;var src='';try{src=String(req.m['631832']||'');}catch(_){}var item={chunkGlobal:name,moduleId:'631832',factoryLength:src.length,loaded:!!(req.c&&req.c['631832']),exportKeys:safeExports(req,'631832'),runApplicationCalls:[],resolvedModules:[],snippets:{}};"
    "var rp=src.indexOf('runApplication(\"App\"');if(rp<0)rp=src.indexOf(\"runApplication('App'\");item.snippets.runApplicationApp=rp>=0?around(src,rp,14000,22000):'';"
    "try{var callRe=/([A-Za-z_$][\\w$]*)(?:\\.A)?\\.runApplication\\([\\\"']App[\\\"']/g,m;while((m=callRe.exec(src))&&item.runApplicationCalls.length<20){var alias=m[1],entry={alias:alias,index:m.index,snippet:around(src,m.index,8000,14000),moduleIds:[]};var assignRe=new RegExp('(?:var|let|const)?\\\\s*'+alias.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+'\\\\s*=\\\\s*r\\\\((\\\\d+)\\\\)','g'),a;while((a=assignRe.exec(src))&&entry.moduleIds.length<10)entry.moduleIds.push(a[1]);if(!entry.moduleIds.length){var simpleRe=new RegExp(alias.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+'=r\\\\((\\\\d+)\\\\)','g'),s;while((s=simpleRe.exec(src))&&entry.moduleIds.length<10)entry.moduleIds.push(s[1]);}item.runApplicationCalls.push(entry);entry.moduleIds.forEach(function(mid){if(req.m[mid])item.resolvedModules.push(moduleItem(req,mid));});}}catch(e){item.resolveError=String(e);}"
    "if(!item.resolvedModules.length){try{var candidates=[];Object.keys(req.m).forEach(function(mid){if(candidates.length>=40)return;var ms='';try{ms=String(req.m[mid]||'');}catch(_){}if(ms.indexOf('runApplication')>=0&&ms.indexOf('initialProps')>=0)candidates.push(moduleItem(req,mid));});item.fallbackModules=candidates;}catch(e){item.fallbackError=String(e);}}"
    "results.push(item);});"
    "if(!results.length)return;window.__scarletXAppRootJotaiProbeDone=true;try{window.webkit.messageHandlers.scarletxAppRootJotaiProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_appRootJotai_viewDidLoad {
    [self sx_appRootJotai_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXAppRootJotaiProbeHandler *handler = objc_getAssociatedObject(self, &SXAppRootJotaiProbeHandlerKey);
    if (!handler) {
        handler = [SXAppRootJotaiProbeHandler new];
        objc_setAssociatedObject(self, &SXAppRootJotaiProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxAppRootJotaiProbe"];
    }

    NSString *script = [self sx_appRootJotaiProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
