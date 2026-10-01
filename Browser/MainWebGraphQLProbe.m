#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXMainGraphQLProbeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXMainGraphQLProbeHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletxGraphQLProbe"] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = (NSDictionary *)message.body;
    if (![[body[@"type"] description] isEqualToString:@"main-graphql-probe"]) return;
    NSMutableDictionary *payload = [body mutableCopy];
    [payload removeObjectForKey:@"type"];
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [payload description];
    [[DiagnosticsStore shared] addEvent:@"Main Web GraphQL request" detail:detail ?: @"{}" url:nil];
}
@end

@interface BrowserViewController (MainWebGraphQLProbe)
@end

@implementation BrowserViewController (MainWebGraphQLProbe)

static char SXMainGraphQLProbeHandlerKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_graphqlProbe_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_graphqlProbeScript {
    return @"(function(){"
    "if(window.__scarletXMainGraphQLProbeInstalled)return;"
    "window.__scarletXMainGraphQLProbeInstalled=true;"
    "var seen={};"
    "function rawURL(input){try{if(input&&typeof Request!=='undefined'&&input instanceof Request)return String(input.url||'');}catch(_){}try{return String(input||'');}catch(_){return '';}}"
    "function parseJSON(v){if(!v)return {};try{var x=JSON.parse(v);return x&&typeof x==='object'?x:{};}catch(_){return {};}}"
    "function emit(transport,input){try{var raw=rawURL(input);if(!raw)return;var u=new URL(raw,location.href);var p=String(u.pathname||'');if(p.indexOf('/graphql/')<0)return;var parts=p.split('/').filter(Boolean),idx=parts.indexOf('graphql');var queryId=idx>=0&&parts.length>idx+1?String(parts[idx+1]||''):'';var operation=idx>=0&&parts.length>idx+2?String(parts[idx+2]||''):'';var vars=parseJSON(u.searchParams.get('variables'));var features=parseJSON(u.searchParams.get('features'));var variableKeys=Object.keys(vars).slice(0,50);var selected={};variableKeys.forEach(function(k){var v=vars[k];if(!(/^(userId|count|cursor|includePromotedContent|with[A-Za-z0-9_]+)$/.test(k)))return;if(typeof v==='string'||typeof v==='number'||typeof v==='boolean'||v===null)selected[k]=v;});var featureKeys=Object.keys(features).slice(0,100);var dedupe=transport+'|'+p+'|'+String(selected.userId||'')+'|'+String(selected.cursor||'')+'|'+String(selected.count||'');if(seen[dedupe])return;seen[dedupe]=1;window.webkit.messageHandlers.scarletxGraphQLProbe.postMessage({type:'main-graphql-probe',transport:String(transport||''),queryId:queryId,operation:operation,path:p,pagePath:String(location.pathname||''),variableKeys:variableKeys,variables:selected,featureKeys:featureKeys});}catch(_){}}"
    "try{var originalFetch=window.fetch;if(typeof originalFetch==='function'){window.fetch=function(input){emit('fetch',input);return originalFetch.apply(this,arguments);};}}catch(_){}"
    "try{var originalOpen=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(method,url){try{this.__scarletXGraphQLURL=rawURL(url);}catch(_){}return originalOpen.apply(this,arguments);};var originalSend=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.send=function(){try{emit('xhr',this.__scarletXGraphQLURL||'');}catch(_){}return originalSend.apply(this,arguments);};}catch(_){}"
    "})();";
}

- (void)sx_graphqlProbe_viewDidLoad {
    [self sx_graphqlProbe_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXMainGraphQLProbeHandler *handler = objc_getAssociatedObject(self, &SXMainGraphQLProbeHandlerKey);
    if (!handler) {
        handler = [SXMainGraphQLProbeHandler new];
        objc_setAssociatedObject(self, &SXMainGraphQLProbeHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxGraphQLProbe"];
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:[self sx_graphqlProbeScript]
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                       forMainFrameOnly:YES];
        [controller addUserScript:userScript];
    }

    NSString *script = [self sx_graphqlProbeScript];
    [webView evaluateJavaScript:script completionHandler:nil];
    __weak WKWebView *weakWebView = webView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WKWebView *strongWebView = weakWebView;
        if (strongWebView) [strongWebView evaluateJavaScript:script completionHandler:nil];
    });
}

@end
