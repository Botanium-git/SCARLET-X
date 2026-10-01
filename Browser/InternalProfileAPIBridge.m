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

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method goHomeOriginal = class_getInstanceMethod(self, @selector(goHome));
        Method goHomeReplacement = class_getInstanceMethod(self, @selector(sx_internalProfileAPI_goHome));
        if (goHomeOriginal && goHomeReplacement) method_exchangeImplementations(goHomeOriginal, goHomeReplacement);

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
            "post({type:'factory-enter',moduleId:'923187',alreadyCached:!!(req.c&&req.c['923187'])});"
            "var originalD=req.d,cachedOriginalW=null,cachedWrappedW=null;"
            "req.d=function(target,defs){"
              "try{"
                "post({type:'req-d',defsType:typeof defs,isArray:Array.isArray(defs),defsKeys:defs&&typeof defs==='object'?Object.keys(defs).slice(0,40):[]});"
                "if(defs&&typeof defs==='object'&&!Array.isArray(defs)&&typeof defs.W==='function'){"
                  "var copy={};Object.keys(defs).forEach(function(k){copy[k]=defs[k];});"
                  "var originalGetter=defs.W;"
                  "copy.W=function(){"
                    "post({type:'W-getter'});"
                    "var originalW=originalGetter();"
                    "post({type:'W-getter-result',valueType:typeof originalW,name:originalW&&originalW.name||'',length:originalW&&originalW.length||0});"
                    "if(typeof originalW!=='function')return originalW;"
                    "if(cachedWrappedW&&cachedOriginalW===originalW)return cachedWrappedW;"
                    "cachedOriginalW=originalW;"
                    "cachedWrappedW=function(){"
                      "var arg0=arguments&&arguments.length?arguments[0]:null;"
                      "var loggedInUserId=arg0&&arg0.loggedInUserId!=null?String(arg0.loggedInUserId):'';"
                      "post({type:'W-call',loggedInUserId:loggedInUserId,arg0Keys:arg0&&typeof arg0==='object'?Object.keys(arg0).slice(0,40):[]});"
                      "var result=originalW.apply(this,arguments);"
                      "post({type:'W-return',resultType:typeof result,resultKeys:result&&typeof result==='object'?Object.keys(result).slice(0,40):[]});"
                      "try{"
                        "if(result&&result.api&&typeof result.api.withEndpoint==='function'){"
                          "window.__scarletXAPI=result.api;"
                          "window.__scarletXAPIJotaiStore=result.jotaiStore||null;"
                          "window.__scarletXAPICapturedAt=Date.now();"
                          "if(!window.__scarletXAPICapturePosted){"
                            "window.__scarletXAPICapturePosted=true;"
                            "post({type:'api-captured',loggedInUserId:loggedInUserId,hasWithEndpoint:typeof result.api.withEndpoint==='function',hasJotaiStore:!!result.jotaiStore,serviceKeys:Object.keys(result).slice(0,40),apiKeys:Object.keys(result.api).slice(0,60)});"
                          "}"
                          "if(loggedInUserId&&!window.__scarletXAutoFetchStarted){"
                            "window.__scarletXAutoFetchStarted=true;"
                            "try{"
                              "var epm=req(923288),factory=epm&&epm.Ay,endpoint=typeof factory==='function'?result.api.withEndpoint(factory):null;"
                              "if(!endpoint||typeof endpoint.fetchUserOriginals!=='function'){post({type:'auto-fetch-error',stage:'endpoint',loggedInUserId:loggedInUserId,endpointKeys:endpoint&&typeof endpoint==='object'?Object.keys(endpoint).slice(0,80):[]});}"
                              "else{"
                                "post({type:'auto-fetch-started',loggedInUserId:loggedInUserId,endpointKeys:Object.keys(endpoint).slice(0,80)});"
                                "Promise.resolve(endpoint.fetchUserOriginals({userId:loggedInUserId,count:5,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false})).then(function(v){"
                                  "var json='';try{json=JSON.stringify(v);}catch(e){json='[JSON stringify failed: '+String(e)+']';}"
                                  "if(json.length>180000)json=json.slice(0,180000)+'...[truncated]';"
                                  "post({type:'auto-fetch-success',loggedInUserId:loggedInUserId,resultType:typeof v,resultKeys:v&&typeof v==='object'?Object.keys(v).slice(0,80):[],resultJSON:json});"
                                "}).catch(function(e){post({type:'auto-fetch-error',stage:'request',loggedInUserId:loggedInUserId,message:String(e&&e.stack||e)});});"
                              "}"
                            "}catch(e){post({type:'auto-fetch-error',stage:'exception',loggedInUserId:loggedInUserId,message:String(e&&e.stack||e)});}"
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

- (void)sx_internalProfileAPI_installBeforeFirstNavigation {
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) {
        [[DiagnosticsStore shared] addEvent:@"Internal profile API pre-navigation install failed" detail:@"webView unavailable before goHome" url:nil];
        return;
    }

    WKUserContentController *controller = webView.configuration.userContentController;
    if (!controller) {
        [[DiagnosticsStore shared] addEvent:@"Internal profile API pre-navigation install failed" detail:@"userContentController unavailable before goHome" url:webView.URL];
        return;
    }

    SXInternalProfileAPIHandler *handler = objc_getAssociatedObject(self, &SXInternalProfileAPIHandlerKey);
    if (!handler) {
        handler = [SXInternalProfileAPIHandler new];
        objc_setAssociatedObject(self, &SXInternalProfileAPIHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller addScriptMessageHandler:handler name:@"scarletxInternalProfileAPI"];

        WKUserScript *hook = [[WKUserScript alloc] initWithSource:[self sx_internalProfileAPI_documentStartScript]
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:YES];
        [controller addUserScript:hook];
        [[DiagnosticsStore shared] addEvent:@"Internal profile API pre-navigation installed"
                                     detail:@"923187.W capture installed before first goHome navigation"
                                        url:webView.URL];
    }
}

- (void)sx_internalProfileAPI_goHome {
    [self sx_internalProfileAPI_installBeforeFirstNavigation];
    [self sx_internalProfileAPI_goHome];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) return;
    NSString *probe = [self sx_internalProfileAPI_fiberRecoveryScript];
    __weak WKWebView *weakWebView = webView;
    for (NSNumber *delay in @[@3.0, @6.0, @10.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WKWebView *strongWebView = weakWebView;
            if (!strongWebView) return;
            [strongWebView evaluateJavaScript:probe completionHandler:^(id result, NSError *error) {
                if (error) [[DiagnosticsStore shared] addError:@"Internal profile API fiber recovery evaluate failed" error:error url:strongWebView.URL];
            }];
        });
    }
}

- (NSString *)sx_internalProfileAPI_fiberRecoveryScript {
    return @"(function(){"
    "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
    "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
    "function addUnique(a,v){if(!v||typeof v!=='object')return;if(a.indexOf(v)<0)a.push(v);}"
    "try{"
      "var req=null,q=window.webpackChunk_twitter_responsive_web;"
      "if(!Array.isArray(q)){post({type:'fiber-recovery',stage:'no-webpack'});return;}"
      "var marker=940000000+Math.floor(Math.random()*50000000);q.push([[marker],{},function(r){req=r;}]);"
      "if(!req){post({type:'fiber-recovery',stage:'no-require'});return;}"
      "var atoms=null;try{atoms=req(302983);}catch(e){}"
      "var nodes=[];"
      "['[data-testid=primaryColumn]','[data-testid=DashButton_ProfileIcon_Link]','main','body'].forEach(function(s){try{var n=document.querySelector(s);if(n)nodes.push(n);}catch(_){}});"
      "try{Array.prototype.slice.call(document.querySelectorAll('article,[role=main] div')).slice(0,120).forEach(function(n){nodes.push(n);});}catch(_){ }"
      "var candidates=[],reduxStores=[],fiberCount=0,contextCount=0;"
      "for(var ni=0;ni<nodes.length;ni++){"
        "var f=fiberOf(nodes[ni]);"
        "for(var d=0;f&&d<120;d++,f=f.return){"
          "fiberCount++;"
          "var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){ }"
          "for(var ci=0;c&&ci<30;ci++){"
            "contextCount++;var vals=[];"
            "try{vals.push(c.memoizedValue);}catch(_){ }"
            "try{if(c.context){vals.push(c.context._currentValue);vals.push(c.context._currentValue2);}}catch(_){ }"
            "for(var vi=0;vi<vals.length;vi++){var v=vals[vi];"
              "if(v&&typeof v==='object'){"
                "if(typeof v.get==='function'&&typeof v.set==='function'&&typeof v.sub==='function')addUnique(candidates,v);"
                "var rs=(v.store&&typeof v.store==='object')?v.store:v;"
                "if(rs&&typeof rs.getState==='function'&&typeof rs.dispatch==='function'&&typeof rs.subscribe==='function')addUnique(reduxStores,rs);"
              "}"
            "}"
            "try{c=c.next;}catch(_){break;}"
          "}"
        "}"
      "}"
      "var api=null,jotaiIndex=-1;"
      "if(atoms&&atoms.S9){for(var i=0;i<candidates.length;i++){try{var x=candidates[i].get(atoms.S9);if(x&&typeof x.withEndpoint==='function'){api=x;jotaiIndex=i;break;}}catch(_){}}}"
      "var uid='';var reduxSummary=[];"
      "for(var ri=0;ri<reduxStores.length;ri++){"
        "try{var st=reduxStores[ri].getState();var session=st&&st.session;var s={index:ri,topKeys:st&&typeof st==='object'?Object.keys(st).slice(0,50):[],sessionKeys:session&&typeof session==='object'?Object.keys(session).slice(0,40):[]};reduxSummary.push(s);"
          "var vals=[session&&session.user_id,session&&session.userId,session&&session.user&&session.user.id_str,st&&st.loggedInUserId,st&&st.currentUserId];"
          "for(var ui=0;ui<vals.length;ui++){if(vals[ui]!=null&&String(vals[ui]).length){uid=String(vals[ui]);break;}}"
          "if(uid)break;"
        "}catch(_){ }"
      "}"
      "post({type:'fiber-recovery',stage:'scan',fiberCount:fiberCount,contextCount:contextCount,jotaiCandidates:candidates.length,reduxCandidates:reduxStores.length,jotaiMatch:jotaiIndex,apiFound:!!api,userId:uid,reduxSummary:reduxSummary});"
      "if(!api)return;"
      "window.__scarletXAPI=api;window.__scarletXAPICapturedAt=Date.now();"
      "post({type:'api-captured-via-fiber',apiKeys:Object.keys(api).slice(0,80),userId:uid});"
      "if(!uid)return;"
      "try{var epm=req(923288),factory=epm&&epm.Ay,endpoint=typeof factory==='function'?api.withEndpoint(factory):null;"
        "if(!endpoint||typeof endpoint.fetchUserOriginals!=='function'){post({type:'fiber-fetch-error',stage:'endpoint',endpointKeys:endpoint&&typeof endpoint==='object'?Object.keys(endpoint).slice(0,80):[]});return;}"
        "post({type:'fiber-fetch-started',userId:uid,endpointKeys:Object.keys(endpoint).slice(0,80)});"
        "Promise.resolve(endpoint.fetchUserOriginals({userId:uid,count:5,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false})).then(function(v){"
          "var json='';try{json=JSON.stringify(v);}catch(e){json='[JSON stringify failed: '+String(e)+']';}"
          "if(json.length>180000)json=json.slice(0,180000)+'...[truncated]';"
          "post({type:'fiber-fetch-success',userId:uid,resultType:typeof v,resultKeys:v&&typeof v==='object'?Object.keys(v).slice(0,80):[],resultJSON:json});"
        "}).catch(function(e){post({type:'fiber-fetch-error',stage:'request',userId:uid,message:String(e&&e.stack||e)});});"
      "}catch(e){post({type:'fiber-fetch-error',stage:'exception',userId:uid,message:String(e&&e.stack||e)});}"
    "}catch(e){post({type:'fiber-recovery',stage:'exception',message:String(e&&e.stack||e)});}"
    "})();";
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
