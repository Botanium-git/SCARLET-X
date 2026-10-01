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
    NSString *type = [body[@"type"] isKindOfClass:NSString.class] ? body[@"type"] : @"";
    if (![type isEqualToString:@"main-graphql-probe"] && ![type isEqualToString:@"main-webpack-probe"]) return;
    NSMutableDictionary *payload = [body mutableCopy];
    [payload removeObjectForKey:@"type"];
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [payload description];
    NSString *event = [type isEqualToString:@"main-webpack-probe"] ? @"Main Web webpack probe" : @"Main Web GraphQL request";
    [[DiagnosticsStore shared] addEvent:event detail:detail ?: @"{}" url:nil];
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
    "var seen={};var webpackScanned=false;"
    "function rawURL(input){try{if(input&&typeof Request!=='undefined'&&input instanceof Request)return String(input.url||'');}catch(_){}try{return String(input||'');}catch(_){return '';}}"
    "function parseJSON(v){if(!v)return {};try{var x=JSON.parse(v);return x&&typeof x==='object'?x:{};}catch(_){return {};}}"
    "function stackURLs(stack){var out=[];String(stack||'').split('\\n').forEach(function(line){var m=line.match(/https?:\\/\\/[^\\s)]+/g)||[];m.forEach(function(v){if(out.indexOf(v)<0&&out.length<20)out.push(v);});});return out;}"
    "function safeExports(req,id){var out=[];try{var c=req&&req.c&&req.c[id],ex=c&&c.exports;if(typeof ex==='function')out=['<function>'];else if(ex&&typeof ex==='object')out=Object.keys(ex).slice(0,60);}catch(_){}return out;}"
    "function around(src,needle,before,after){try{var p=String(src||'').indexOf(needle);if(p<0)return '';return String(src||'').slice(Math.max(0,p-(before||700)),Math.min(String(src||'').length,p+(after||2200)));}catch(_){return '';}}"
    "function describeValue(v){var out={type:typeof v};try{if(typeof v==='function'){out.name=String(v.name||'');out.length=Number(v.length||0);out.source=String(v).slice(0,12000);}else if(v&&typeof v==='object'){out.keys=Object.keys(v).slice(0,80);}}catch(e){out.error=String(e);}return out;}"
    "function inspectModule(req,name,id){var out={chunkGlobal:String(name||''),moduleId:String(id||''),loaded:false,exportKeys:[],factoryLength:0,snippets:{}};try{var factory=req&&req.m&&req.m[id],src=String(factory||'');out.factoryLength=src.length;out.snippets.fetchUserOriginals=around(src,'fetchUserOriginals',1200,4200);out.snippets.apiClient=around(src,'apiClient',1000,3200);out.snippets.graphQL=around(src,'graphQL',1000,3200);out.snippets.targetModule=around(src,'502130',1000,3200);var c=req&&req.c&&req.c[id];if(c){out.loaded=true;var ex=c.exports;out.exportKeys=typeof ex==='function'?['<function>']:(ex&&typeof ex==='object'?Object.keys(ex).slice(0,80):[]);if(ex&&typeof ex==='object'&&Object.prototype.hasOwnProperty.call(ex,'Ay'))out.Ay=describeValue(ex.Ay);else if(typeof ex==='function')out.moduleExport=describeValue(ex);}}catch(e){out.error=String(e);}return out;}"
    "function scanApiFactoryReferrers(req,name){var out=[];try{if(!req||!req.m)return out;var ids=Object.keys(req.m);for(var i=0;i<ids.length&&out.length<50;i++){var id=String(ids[i]);if(id==='923288')continue;var src='';try{src=String(req.m[id]||'');}catch(_){continue;}var pos=src.indexOf('923288');if(pos<0)continue;out.push({chunkGlobal:String(name||''),moduleId:id,sourceLength:src.length,exportKeys:safeExports(req,id),loaded:!!(req.c&&req.c[id]),snippet:src.slice(Math.max(0,pos-1800),Math.min(src.length,pos+5200)),AySnippet:around(src,'.Ay',1400,3600),apiClientSnippet:around(src,'apiClient',1400,3600),featureSwitchesSnippet:around(src,'featureSwitches',1400,3600)});}}catch(e){out.push({error:String(e)});}return out;}"
    "function scanWebpack(queryId,operation){if(webpackScanned)return;webpackScanned=true;var globals=[];try{globals=Object.keys(window).filter(function(k){try{return /^webpackChunk/.test(k)&&Array.isArray(window[k]);}catch(_){return false;}}).slice(0,12);}catch(_){}var hits=[],referrers=[],inspections=[],apiFactoryReferrers=[],scanned=[];globals.forEach(function(name,gi){var arr=null,req=null;try{arr=window[name];var marker=900000000+Math.floor(Math.random()*90000000)+gi;arr.push([[marker],{},function(r){req=r;}]);}catch(e){}if(!req||!req.m)return;var ids=[];try{ids=Object.keys(req.m);}catch(_){}scanned.push({chunkGlobal:name,moduleCount:ids.length});for(var i=0;i<ids.length&&hits.length<30;i++){var id=ids[i],factory=null,src='';try{factory=req.m[id];src=String(factory||'');}catch(_){continue;}var opIndex=src.indexOf(operation),idIndex=src.indexOf(queryId),idx=opIndex>=0?opIndex:idIndex;if(idx<0)continue;var start=Math.max(0,idx-700),end=Math.min(src.length,idx+1700);hits.push({chunkGlobal:name,moduleId:String(id),matchedOperation:opIndex>=0,matchedQueryId:idIndex>=0,sourceLength:src.length,exportKeys:safeExports(req,id),snippet:src.slice(start,end)});}var targetIds=hits.filter(function(h){return h.chunkGlobal===name;}).map(function(h){return String(h.moduleId||'');}).filter(Boolean);if(targetIds.length){for(var j=0;j<ids.length&&referrers.length<80;j++){var rid=String(ids[j]);if(targetIds.indexOf(rid)>=0)continue;var rsrc='';try{rsrc=String(req.m[rid]||'');}catch(_){continue;}for(var t=0;t<targetIds.length;t++){var target=targetIds[t],pos=rsrc.indexOf(target);if(pos<0)continue;var rs=Math.max(0,pos-900),re=Math.min(rsrc.length,pos+2200);referrers.push({chunkGlobal:name,moduleId:rid,targetModuleId:target,sourceLength:rsrc.length,exportKeys:safeExports(req,rid),snippet:rsrc.slice(rs,re)});break;}}}if(req.m['923288']){inspections.push(inspectModule(req,name,'923288'));apiFactoryReferrers=apiFactoryReferrers.concat(scanApiFactoryReferrers(req,name));}});try{window.webkit.messageHandlers.scarletxGraphQLProbe.postMessage({type:'main-webpack-probe',operation:String(operation||''),queryId:String(queryId||''),pagePath:String(location.pathname||''),chunkGlobals:globals,scanned:scanned,hits:hits,referrers:referrers,inspections:inspections,apiFactoryReferrers:apiFactoryReferrers});}catch(_){}}"
    "function emit(transport,input,stack){try{var raw=rawURL(input);if(!raw)return;var u=new URL(raw,location.href);var p=String(u.pathname||'');if(p.indexOf('/graphql/')<0)return;var parts=p.split('/').filter(Boolean),idx=parts.indexOf('graphql');var queryId=idx>=0&&parts.length>idx+1?String(parts[idx+1]||''):'';var operation=idx>=0&&parts.length>idx+2?String(parts[idx+2]||''):'';var vars=parseJSON(u.searchParams.get('variables'));var features=parseJSON(u.searchParams.get('features'));var variableKeys=Object.keys(vars).slice(0,50);var selected={};variableKeys.forEach(function(k){var v=vars[k];if(!(/^(userId|count|cursor|includePromotedContent|with[A-Za-z0-9_]+)$/.test(k)))return;if(typeof v==='string'||typeof v==='number'||typeof v==='boolean'||v===null)selected[k]=v;});var featureKeys=Object.keys(features).slice(0,100);var dedupe=transport+'|'+p+'|'+String(selected.userId||'')+'|'+String(selected.cursor||'')+'|'+String(selected.count||'');if(seen[dedupe])return;seen[dedupe]=1;var payload={type:'main-graphql-probe',transport:String(transport||''),queryId:queryId,operation:operation,path:p,pagePath:String(location.pathname||''),variableKeys:variableKeys,variables:selected,featureKeys:featureKeys};if(operation==='UserOriginalsTimeline'){payload.stack=String(stack||'').slice(0,12000);payload.stackURLs=stackURLs(stack);}window.webkit.messageHandlers.scarletxGraphQLProbe.postMessage(payload);if(operation==='UserOriginalsTimeline')setTimeout(function(){scanWebpack(queryId,operation);},0);}catch(_){}}"
    "try{var originalFetch=window.fetch;if(typeof originalFetch==='function'){window.fetch=function(input){var st='';try{st=(new Error('ScarletX fetch UserOriginalsTimeline probe')).stack||'';}catch(_){}emit('fetch',input,st);return originalFetch.apply(this,arguments);};}}catch(_){}"
    "try{var originalOpen=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(method,url){try{this.__scarletXGraphQLURL=rawURL(url);}catch(_){}return originalOpen.apply(this,arguments);};var originalSend=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.send=function(){var st='';try{st=(new Error('ScarletX xhr UserOriginalsTimeline probe')).stack||'';}catch(_){}try{emit('xhr',this.__scarletXGraphQLURL||'',st);}catch(_){}return originalSend.apply(this,arguments);};}catch(_){}"
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
