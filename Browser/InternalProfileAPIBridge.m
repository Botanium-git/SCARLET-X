#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface SXInternalProfileAPIHandler : NSObject <WKScriptMessageHandler>
@end

@implementation SXInternalProfileAPIHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"scarletxInternalProfileAPI"]) return;
    id body = message.body;
    NSString *type = [body isKindOfClass:NSDictionary.class] && [body[@"type"] isKindOfClass:NSString.class] ? body[@"type"] : @"message";
    NSString *title = [NSString stringWithFormat:@"Internal profile API %@", type];
    NSString *detail = nil;
    if ([NSJSONSerialization isValidJSONObject:body]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        if (data) detail = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (!detail) detail = [body description] ?: @"";
    [[DiagnosticsStore shared] addEvent:title detail:detail url:nil];
}
@end

@interface BrowserViewController (InternalProfileAPIBridge)
@end

@implementation BrowserViewController (InternalProfileAPIBridge)

static char SXInternalProfileAPIHandlerKey;
static char SXInternalProfileAPIReloadKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method viewDidLoadOriginal = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method viewDidLoadReplacement = class_getInstanceMethod(self, @selector(sx_internalProfileAPI_viewDidLoad));
        if (viewDidLoadOriginal && viewDidLoadReplacement) method_exchangeImplementations(viewDidLoadOriginal, viewDidLoadReplacement);

        Method profileOriginal = class_getInstanceMethod(self, @selector(nativeDrawerDidSelectNativeProfile:));
        Method profileReplacement = class_getInstanceMethod(self, @selector(sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:));
        if (profileOriginal && profileReplacement) method_exchangeImplementations(profileOriginal, profileReplacement);
    });
}

- (NSString *)sx_internalProfileAPI_documentStartScript {
    return @"(function(){"
    "if(window.__scarletXInternalAPIHookInstalled)return;"
    "window.__scarletXInternalAPIHookInstalled=true;"
    "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
    "var name='webpackChunk_twitter_responsive_web';"
    "var q=window[name]=window[name]||[];"
    "if(q.__scarletXBootstrapPushHooked)return;"
    "q.__scarletXBootstrapPushHooked=true;"
    "var originalPush=q.push;"
    "q.push=function(){"
      "try{"
        "for(var ai=0;ai<arguments.length;ai++){"
          "var chunk=arguments[ai],mods=chunk&&chunk[1];"
          "if(!mods||!mods['923187'])continue;"
          "var originalFactory=mods['923187'];"
          "if(!originalFactory||originalFactory.__scarletXWrapped)continue;"
          "post({type:'bootstrap-module-seen',moduleId:'923187'});"
          "var wrapped=function(module,exports,req){"
            "var originalD=req.d,cachedOriginalW=null,cachedWrappedW=null;"
            "req.d=function(target,defs){"
              "try{"
                "if(defs&&typeof defs==='object'&&!Array.isArray(defs)&&typeof defs.W==='function'){"
                  "var copy={};Object.keys(defs).forEach(function(k){copy[k]=defs[k];});"
                  "var originalGetter=defs.W;"
                  "copy.W=function(){"
                    "var originalW=originalGetter();"
                    "if(typeof originalW!=='function')return originalW;"
                    "if(cachedWrappedW&&cachedOriginalW===originalW)return cachedWrappedW;"
                    "cachedOriginalW=originalW;"
                    "cachedWrappedW=function(){"
                      "var result=originalW.apply(this,arguments);"
                      "try{"
                        "if(result&&result.api&&typeof result.api.withEndpoint==='function'){"
                          "window.__scarletXAPI=result.api;"
                          "window.__scarletXAPIJotaiStore=result.jotaiStore||null;"
                          "window.__scarletXAPICapturedAt=Date.now();"
                          "if(!window.__scarletXAPICapturePosted){"
                            "window.__scarletXAPICapturePosted=true;"
                            "post({type:'api-captured',hasWithEndpoint:typeof result.api.withEndpoint==='function',hasJotaiStore:!!result.jotaiStore,serviceKeys:Object.keys(result).slice(0,40),apiKeys:Object.keys(result.api).slice(0,60)});"
                          "}"
                        "}"
                      "}catch(e){post({type:'capture-error',stage:'W-return',message:String(e&&e.stack||e)});}"
                      "return result;"
                    "};"
                    "return cachedWrappedW;"
                  "};"
                  "return originalD.call(req,target,copy);"
                "}"
              "}catch(e){post({type:'capture-error',stage:'req.d',message:String(e&&e.stack||e)});}"
              "return originalD.call(req,target,defs);"
            "};"
            "try{return originalFactory.call(this,module,exports,req);}finally{req.d=originalD;}"
          "};"
          "wrapped.__scarletXWrapped=true;"
          "mods['923187']=wrapped;"
        "}"
      "}catch(e){post({type:'capture-error',stage:'push',message:String(e&&e.stack||e)});}"
      "return originalPush.apply(this,arguments);"
    "};"
    "})();";
}

- (void)sx_internalProfileAPI_viewDidLoad {
    [self sx_internalProfileAPI_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) return;

    SXInternalProfileAPIHandler *handler = objc_getAssociatedObject(self, &SXInternalProfileAPIHandlerKey);
    if (!handler) {
        handler = [SXInternalProfileAPIHandler new];
        objc_setAssociatedObject(self, &SXInternalProfileAPIHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxInternalProfileAPI"];
        WKUserScript *hook = [[WKUserScript alloc] initWithSource:[self sx_internalProfileAPI_documentStartScript]
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:YES];
        [controller addUserScript:hook];
        [[DiagnosticsStore shared] addEvent:@"Internal profile API bridge installed" detail:@"document-start module 923187.W capture installed" url:webView.URL];
    }

    if (![objc_getAssociatedObject(self, &SXInternalProfileAPIReloadKey) boolValue]) {
        objc_setAssociatedObject(self, &SXInternalProfileAPIReloadKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak WKWebView *weakWebView = webView;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (strongWebView) {
                [[DiagnosticsStore shared] addEvent:@"Internal profile API bridge reload" detail:@"reloading once so bootstrap capture is active before X webpack executes" url:strongWebView.URL];
                [strongWebView reload];
            }
        });
    }
}

- (NSString *)sx_internalProfileAPI_fetchScriptForUserId:(NSString *)userId {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[userId ?: @""] options:0 error:nil];
    NSString *array = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[\"\"]";
    NSString *uidLiteral = array.length >= 2 ? [array substringWithRange:NSMakeRange(1, array.length - 2)] : @"\"\"";

    return [NSString stringWithFormat:@"(function(){"
      "var uid=%@;"
      "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
      "try{"
        "var api=window.__scarletXAPI;"
        "if(!api||typeof api.withEndpoint!=='function'){post({type:'fetch-error',stage:'api',message:'captured API object is unavailable',uid:uid,apiType:typeof api});return {started:false,stage:'api'};}"
        "var req=null,q=window.webpackChunk_twitter_responsive_web;"
        "if(!Array.isArray(q)){post({type:'fetch-error',stage:'webpack',message:'webpack chunk global unavailable',uid:uid});return {started:false,stage:'webpack'};}"
        "var marker=910000000+Math.floor(Math.random()*80000000);"
        "q.push([[marker],{},function(r){req=r;}]);"
        "if(!req){post({type:'fetch-error',stage:'require',message:'webpack require unavailable',uid:uid});return {started:false,stage:'require'};}"
        "var endpointModule=req(923288),factory=endpointModule&&endpointModule.Ay;"
        "if(typeof factory!=='function'){post({type:'fetch-error',stage:'endpoint-factory',message:'923288.Ay unavailable',uid:uid});return {started:false,stage:'endpoint-factory'};}"
        "var endpoint=api.withEndpoint(factory);"
        "if(!endpoint||typeof endpoint.fetchUserOriginals!=='function'){post({type:'fetch-error',stage:'endpoint',message:'fetchUserOriginals unavailable',uid:uid,keys:endpoint&&typeof endpoint==='object'?Object.keys(endpoint).slice(0,80):[]});return {started:false,stage:'endpoint'};}"
        "post({type:'fetch-started',uid:uid,apiCapturedAt:Number(window.__scarletXAPICapturedAt||0),endpointKeys:Object.keys(endpoint).slice(0,80)});"
        "Promise.resolve(endpoint.fetchUserOriginals({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false})).then(function(result){"
          "var json='';try{json=JSON.stringify(result);}catch(e){json='[JSON stringify failed: '+String(e)+']';}"
          "if(json.length>180000)json=json.slice(0,180000)+'...[truncated]';"
          "post({type:'fetch-success',uid:uid,resultType:typeof result,resultKeys:result&&typeof result==='object'?Object.keys(result).slice(0,80):[],resultJSON:json});"
        "}).catch(function(e){post({type:'fetch-error',stage:'request',uid:uid,message:String(e&&e.stack||e)});});"
        "return {started:true,uid:uid};"
      "}catch(e){post({type:'fetch-error',stage:'exception',uid:uid,message:String(e&&e.stack||e)});return {started:false,stage:'exception'};}"
    "})()", uidLiteral];
}

- (void)sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer {
    NSDictionary *base = [drawer.profileData isKindOfClass:NSDictionary.class] ? drawer.profileData : @{};
    NSDictionary *probe = [base[@"followerProbe"] isKindOfClass:NSDictionary.class] ? base[@"followerProbe"] : @{};
    NSString *userId = [probe[@"currentUserId"] isKindOfClass:NSString.class] ? probe[@"currentUserId"] : @"";
    if (userId.length == 0 && [base[@"userId"] isKindOfClass:NSString.class]) userId = base[@"userId"];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry" detail:[NSString stringWithFormat:@"userId=%@ webView=%@", userId.length ? userId : @"<empty>", [webView isKindOfClass:WKWebView.class] ? @"YES" : @"NO"] url:[webView isKindOfClass:WKWebView.class] ? webView.URL : nil];

    [self sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:drawer];

    if (![webView isKindOfClass:WKWebView.class]) return;
    if (userId.length == 0) {
        [[DiagnosticsStore shared] addEvent:@"Internal profile API fetch skipped" detail:@"current profile userId was unavailable before native profile open" url:webView.URL];
        return;
    }

    [[DiagnosticsStore shared] addEvent:@"Internal profile API fetch scheduled" detail:[NSString stringWithFormat:@"userId=%@", userId] url:webView.URL];
    NSString *script = [self sx_internalProfileAPI_fetchScriptForUserId:userId];
    __weak WKWebView *weakWebView = webView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WKWebView *strongWebView = weakWebView;
        if (!strongWebView) return;
        [strongWebView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if (error) {
                [[DiagnosticsStore shared] addError:@"Internal profile API evaluate failed" error:error url:strongWebView.URL];
                return;
            }
            [[DiagnosticsStore shared] addEvent:@"Internal profile API evaluate returned" detail:[result description] ?: @"" url:strongWebView.URL];
        }];
    });
}

@end
