#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (InternalProfileAPIProfileEntryRecovery243Private)
- (void)sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer;
@end

@implementation BrowserViewController (InternalProfileAPIProfileEntryRecovery240)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls=self;
        Method target=class_getInstanceMethod(cls,@selector(sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:));
        Method replacement=class_getInstanceMethod(cls,@selector(sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:));
        if(target&&replacement){
            method_exchangeImplementations(target,replacement);
        }
    });
}

- (NSString *)sx243_profileEntryRecoveryScript {
    return @"(function(){"
    "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
    "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
    "function addUnique(a,v){if(!v||typeof v!=='object')return;if(a.indexOf(v)<0)a.push(v);}"
    "function safeDataGet(obj,key){"
      "if(!obj||(typeof obj!=='object'&&typeof obj!=='function'))return undefined;"
      "var p=obj,depth=0;"
      "while(p&&depth<6){"
        "var d=null;try{d=Object.getOwnPropertyDescriptor(p,key);}catch(_){return undefined;}"
        "if(d){if(Object.prototype.hasOwnProperty.call(d,'value'))return d.value;return undefined;}"
        "try{p=Object.getPrototypeOf(p);}catch(_){return undefined;}depth++;"
      "}"
      "return undefined;"
    "}"
    "try{"
      "if(window.__scarletXAPI&&typeof window.__scarletXAPI.withEndpoint==='function'){post({type:'profile-entry-recovery243',stage:'already-captured',apiFound:true});return {apiFound:true,stage:'already-captured'};}"
      "var req=null,q=window.webpackChunk_twitter_responsive_web;"
      "if(!Array.isArray(q)){post({type:'profile-entry-recovery243',stage:'no-webpack',apiFound:false});return {apiFound:false,stage:'no-webpack'};}"
      "var marker=943000000+Math.floor(Math.random()*50000000);"
      "q.push([[marker],{},function(r){req=r;}]);"
      "if(!req){post({type:'profile-entry-recovery243',stage:'no-require',apiFound:false});return {apiFound:false,stage:'no-require'};}"
      "var nodes=[];"
      "['[data-testid=primaryColumn]','[data-testid=DashButton_ProfileIcon_Link]','main','body'].forEach(function(s){try{var n=document.querySelector(s);if(n)nodes.push(n);}catch(_){}});"
      "try{Array.prototype.slice.call(document.querySelectorAll('article,[role=main] div')).slice(0,120).forEach(function(n){nodes.push(n);});}catch(_){ }"
      "var stores=[],fiberCount=0,contextCount=0;"
      "for(var ni=0;ni<nodes.length;ni++){"
        "var f=fiberOf(nodes[ni]);"
        "for(var d=0;f&&d<120;d++,f=f.return){"
          "fiberCount++;"
          "var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){ }"
          "for(var ci=0;c&&ci<30;ci++){"
            "contextCount++;var vals=[];"
            "try{vals.push(c.memoizedValue);}catch(_){ }"
            "try{if(c.context){vals.push(c.context._currentValue);vals.push(c.context._currentValue2);}}catch(_){ }"
            "for(var vi=0;vi<vals.length;vi++){"
              "var v=vals[vi];if(!v||typeof v!=='object')continue;"
              "var get=safeDataGet(v,'get'),set=safeDataGet(v,'set'),sub=safeDataGet(v,'sub');"
              "if(typeof get==='function'&&typeof set==='function'&&typeof sub==='function')addUnique(stores,v);"
            "}"
            "try{c=c.next;}catch(_){break;}"
          "}"
        "}"
      "}"
      "var loaded=[];try{loaded=req.c&&typeof req.c==='object'?Object.keys(req.c):[];}catch(_){loaded=[];}"
      "var jjModules=[],matchedModuleId='',api=null,matchedStore=-1;"
      "for(var li=0;li<loaded.length&&!api;li++){"
        "var mid=String(loaded[li]),ex=null;"
        "try{var cm=req.c[mid];ex=cm&&cm.exports;}catch(_){continue;}"
        "if(!ex||(typeof ex!=='object'&&typeof ex!=='function'))continue;"
        "var jj=null,hasJJ=false;"
        "try{hasJJ=Object.prototype.hasOwnProperty.call(ex,'JJ');if(hasJJ)jj=ex.JJ;}catch(_){continue;}"
        "if(!hasJJ||!jj)continue;"
        "if(jjModules.length<100)jjModules.push(mid);"
        "for(var si=0;si<stores.length&&!api;si++){"
          "try{"
            "var getter=safeDataGet(stores[si],'get');if(typeof getter!=='function')continue;"
            "var value=getter.call(stores[si],jj);"
            "if(value&&typeof safeDataGet(value,'withEndpoint')==='function'){api=value;matchedModuleId=mid;matchedStore=si;break;}"
            "var candidateApi=value&&safeDataGet(value,'api');"
            "if(candidateApi&&typeof safeDataGet(candidateApi,'withEndpoint')==='function'){api=candidateApi;matchedModuleId=mid;matchedStore=si;break;}"
          "}catch(_){ }"
        "}"
      "}"
      "post({type:'profile-entry-recovery243',stage:'scan',fiberCount:fiberCount,contextCount:contextCount,jotaiCandidates:stores.length,loadedModules:loaded.length,jjModules:jjModules,matchedModuleId:matchedModuleId,matchedStore:matchedStore,apiFound:!!api});"
      "if(!api)return {apiFound:false,stage:'scan',jjModules:jjModules};"
      "window.__scarletXAPI=api;window.__scarletXAPICapturedAt=Date.now();"
      "var keys=[];try{keys=Object.keys(api).slice(0,80);}catch(_){ }"
      "post({type:'profile-entry-recovery243',stage:'captured',matchedModuleId:matchedModuleId,matchedStore:matchedStore,apiFound:true,apiKeys:keys});"
      "return {apiFound:true,stage:'captured',matchedModuleId:matchedModuleId};"
    "}catch(e){post({type:'profile-entry-recovery243',stage:'exception',apiFound:false,message:String(e&&e.stack||e)});return {apiFound:false,stage:'exception'};}"
    "})()";
}

- (void)sx243_scheduleProfileEntryRecoveryForWebView:(WKWebView *)webView {
    if(![webView isKindOfClass:WKWebView.class])return;
    NSString *probe=[self sx243_profileEntryRecoveryScript];
    if(probe.length==0)return;

    [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery243 scheduled"
                                 detail:@"delays=0,0.75,2.0,4.5"
                                    url:webView.URL];

    __weak WKWebView *weakWebView=webView;
    for(NSNumber *delay in @[@0.0,@0.75,@2.0,@4.5]){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            WKWebView *strongWebView=weakWebView;
            if(!strongWebView)return;
            [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery243 evaluate"
                                         detail:[NSString stringWithFormat:@"delay=%.2f",delay.doubleValue]
                                            url:strongWebView.URL];
            [strongWebView evaluateJavaScript:probe completionHandler:^(id result,NSError *error){
                if(error){
                    [[DiagnosticsStore shared] addError:@"Internal profile API profile-entry recovery243 evaluate failed" error:error url:strongWebView.URL];
                    return;
                }
                [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery243 returned"
                                             detail:[result description] ?: @""
                                                url:strongWebView.URL];
            }];
        });
    }
}

- (void)sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer {
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    if([webView isKindOfClass:WKWebView.class]){
        [self sx243_scheduleProfileEntryRecoveryForWebView:webView];
    }

    [self sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:drawer];
}

@end
