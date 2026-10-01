#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXAppRegistrationProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXAppRegistrationProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletxAppRegistrationProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [body description];
    [[DiagnosticsStore shared] addEvent:@"Main Web App registration probe" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (AppRegistrationProbe)
@end

@implementation BrowserViewController (AppRegistrationProbe)

static char SXAppRegistrationProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_appRegistration_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_appRegistrationProbeScript {
    return @"(function(){"
    "if(window.__scarletXAppRegistrationProbeDone)return;"
    "function around(src,index,before,after){try{src=String(src||'');index=Number(index||0);return src.slice(Math.max(0,index-(before||2500)),Math.min(src.length,index+(after||7000)));}catch(_){return '';}}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,120);}catch(_){}return out;}"
    "function moduleItem(req,id){var src='';try{src=String(req.m[id]||'');}catch(_){}var item={moduleId:String(id),factoryLength:src.length,loaded:!!(req.c&&req.c[id]),exportKeys:safeExports(req,String(id)),factoryStart:src.slice(0,36000),factoryEnd:src.slice(Math.max(0,src.length-30000)),snippets:{}};function sn(key,needle,b,a){var p=src.indexOf(needle);item.snippets[key]=p>=0?around(src,p,b,a):'';}sn('registerComponent','registerComponent',12000,18000);sn('appLiteral','\"App\"',12000,18000);sn('jotaiStore','jotaiStore',12000,18000);sn('Provider','Provider',12000,18000);sn('storeProp','store:',12000,18000);sn('302983','302983',12000,18000);sn('658009','658009',12000,18000);sn('createElement','createElement',9000,14000);sn('jsx','.jsx',9000,14000);return item;}"
    "function importsOf(src){var out=[],seen={};try{var re=/([A-Za-z_$][\\w$]*)\\s*=\\s*r\\((\\d+)\\)/g,m;while((m=re.exec(src))&&out.length<160){var key=m[1]+':'+m[2];if(!seen[key]){seen[key]=1;out.push({alias:m[1],moduleId:m[2],index:m.index});}}}catch(_){}return out;}"
    "var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}"
    "var results=[];"
    "globals.forEach(function(name,gi){var req=null;try{var marker=870000000+Math.floor(Math.random()*90000000)+gi;window[name].push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m)return;var root={chunkGlobal:name,scannedCount:Object.keys(req.m).length,registrationModules:[]};"
    "try{Object.keys(req.m).forEach(function(mid){if(root.registrationModules.length>=24)return;var src='';try{src=String(req.m[mid]||'');}catch(_){}if(src.indexOf('registerComponent')<0||src.indexOf('App')<0)return;var hits=[];var needles=['registerComponent(\"App\"','registerComponent(\'App\'','registerComponent(\"App\",','registerComponent(\'App\','];for(var ni=0;ni<needles.length;ni++){var p=src.indexOf(needles[ni]);if(p>=0)hits.push(p);}if(!hits.length){var rp=src.indexOf('registerComponent');if(rp>=0&&around(src,rp,2000,5000).indexOf('App')>=0)hits.push(rp);}if(!hits.length)return;var item=moduleItem(req,mid);item.registrationHits=hits.slice(0,12).map(function(p){return{index:p,snippet:around(src,p,12000,22000)};});item.imports=importsOf(src);item.relatedImports=[];item.imports.forEach(function(im){if(item.relatedImports.length>=40)return;var ms='';try{ms=String(req.m[im.moduleId]||'');}catch(_){}if(!ms)return;var relevant=ms.indexOf('jotaiStore')>=0||ms.indexOf('Provider')>=0||ms.indexOf('302983')>=0||ms.indexOf('658009')>=0||ms.indexOf('createContext')>=0||ms.indexOf('store:')>=0;if(relevant){var child=moduleItem(req,im.moduleId);child.importAlias=im.alias;child.importIndex=im.index;item.relatedImports.push(child);}});root.registrationModules.push(item);});}catch(e){root.scanError=String(e);}"
    "if(root.registrationModules.length)results.push(root);});"
    "if(!results.length)return;window.__scarletXAppRegistrationProbeDone=true;try{window.webkit.messageHandlers.scarletxAppRegistrationProbe.postMessage({pagePath:String(location.pathname||''),results:results});}catch(_){}"
    "})();";
}

- (void)sx_appRegistration_viewDidLoad {
    [self sx_appRegistration_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXAppRegistrationProbeHandler *handler = objc_getAssociatedObject(self, &SXAppRegistrationProbeHandlerKey);
    if (!handler) {
        handler = [SXAppRegistrationProbeHandler new];
        objc_setAssociatedObject(self, &SXAppRegistrationProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxAppRegistrationProbe"];
    }

    NSString *script = [self sx_appRegistrationProbeScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@0.75, @2.0, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
        });
    }
}

@end
