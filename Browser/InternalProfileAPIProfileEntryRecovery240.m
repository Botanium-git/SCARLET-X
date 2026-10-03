#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (InternalProfileAPIProfileEntryRecovery244Private)
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

- (NSString *)sx244_profileEntryRecoveryScript {
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
    "function looksLikeAPI(v){return !!(v&&typeof safeDataGet(v,'withEndpoint')==='function');}"
    "function extractAPI(v){if(looksLikeAPI(v))return v;var a=v&&safeDataGet(v,'api');return looksLikeAPI(a)?a:null;}"
    "try{"
      "if(window.__scarletXAPI&&looksLikeAPI(window.__scarletXAPI)){post({type:'profile-entry-recovery244',stage:'already-captured',apiFound:true});return {apiFound:true,stage:'already-captured'};}"
      "var req=null,q=window.webpackChunk_twitter_responsive_web;"
      "if(!Array.isArray(q)){post({type:'profile-entry-recovery244',stage:'no-webpack',apiFound:false});return {apiFound:false,stage:'no-webpack'};}"
      "var marker=944000000+Math.floor(Math.random()*50000000);q.push([[marker],{},function(r){req=r;}]);"
      "if(!req){post({type:'profile-entry-recovery244',stage:'no-require',apiFound:false});return {apiFound:false,stage:'no-require'};}"
      "var nodes=[];"
      "['[data-testid=primaryColumn]','[data-testid=DashButton_ProfileIcon_Link]','main','body'].forEach(function(s){try{var n=document.querySelector(s);if(n)nodes.push(n);}catch(_){}});"
      "try{Array.prototype.slice.call(document.querySelectorAll('article,[role=main] div')).slice(0,120).forEach(function(n){nodes.push(n);});}catch(_){ }"
      "var stores=[],fiberCount=0,contextCount=0;"
      "for(var ni=0;ni<nodes.length;ni++){"
        "var f=fiberOf(nodes[ni]);"
        "for(var d=0;f&&d<120;d++,f=f.return){"
          "fiberCount++;var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){ }"
          "for(var ci=0;c&&ci<30;ci++){"
            "contextCount++;var vals=[];try{vals.push(c.memoizedValue);}catch(_){ }try{if(c.context){vals.push(c.context._currentValue);vals.push(c.context._currentValue2);}}catch(_){ }"
            "for(var vi=0;vi<vals.length;vi++){var v=vals[vi];if(!v||typeof v!=='object')continue;var get=safeDataGet(v,'get'),set=safeDataGet(v,'set'),sub=safeDataGet(v,'sub');if(typeof get==='function'&&typeof set==='function'&&typeof sub==='function')addUnique(stores,v);}"
            "try{c=c.next;}catch(_){break;}"
          "}"
        "}"
      "}"
      "var serviceModuleId='91575';"
      "if(!(req.m&&req.m[serviceModuleId])){"
        "serviceModuleId='';var mids=[];try{mids=Object.keys(req.m||{});}catch(_){mids=[];}"
        "for(var mi=0;mi<mids.length;mi++){var src='';try{src=String(req.m[mids[mi]]||'');}catch(_){continue;}if(src.indexOf('jotaiStore:')>=0&&src.indexOf('relayEnvironment:')>=0&&src.indexOf('api:')>=0){serviceModuleId=String(mids[mi]);break;}}"
      "}"
      "var deps=[],api=null,matchedDep='',matchedExport='',matchedStore=-1,tested=0;"
      "if(serviceModuleId){"
        "var ssrc='';try{ssrc=String(req.m[serviceModuleId]||'');}catch(_){ssrc='';}"
        "var rx=/\\br\\((\\d+)\\)/g,m=null,seen={};"
        "while((m=rx.exec(ssrc))!==null){var dep=String(m[1]);if(!seen[dep]){seen[dep]=1;deps.push(dep);if(deps.length>=160)break;}}"
        "for(var di=0;di<deps.length&&!api;di++){"
          "var depId=deps[di],ex=null;try{ex=req(Number(depId));}catch(_){try{ex=req(depId);}catch(__){ex=null;}}"
          "if(!ex||(typeof ex!=='object'&&typeof ex!=='function'))continue;"
          "var keys=[];try{keys=Object.keys(ex).slice(0,100);}catch(_){keys=[];}"
          "for(var ki=0;ki<keys.length&&!api;ki++){"
            "var key=keys[ki],atom=null;try{atom=ex[key];}catch(_){continue;}"
            "if(!atom||(typeof atom!=='object'&&typeof atom!=='function'))continue;"
            "for(var si=0;si<stores.length&&!api;si++){"
              "try{var getter=safeDataGet(stores[si],'get');if(typeof getter!=='function')continue;tested++;var value=getter.call(stores[si],atom);var found=extractAPI(value);if(found){api=found;matchedDep=depId;matchedExport=String(key);matchedStore=si;break;}}catch(_){ }"
            "}"
          "}"
        "}"
      "}"
      "post({type:'profile-entry-recovery244',stage:'scan',fiberCount:fiberCount,contextCount:contextCount,jotaiCandidates:stores.length,serviceModuleId:serviceModuleId,dependencyCount:deps.length,dependencies:deps.slice(0,80),testedAtoms:tested,matchedDependency:matchedDep,matchedExport:matchedExport,matchedStore:matchedStore,apiFound:!!api});"
      "if(!api)return {apiFound:false,stage:'scan',serviceModuleId:serviceModuleId,dependencyCount:deps.length,testedAtoms:tested};"
      "window.__scarletXAPI=api;window.__scarletXAPICapturedAt=Date.now();"
      "var keys=[];try{keys=Object.keys(api).slice(0,80);}catch(_){ }"
      "post({type:'profile-entry-recovery244',stage:'captured',matchedDependency:matchedDep,matchedExport:matchedExport,matchedStore:matchedStore,apiFound:true,apiKeys:keys});"
      "return {apiFound:true,stage:'captured',matchedDependency:matchedDep,matchedExport:matchedExport};"
    "}catch(e){post({type:'profile-entry-recovery244',stage:'exception',apiFound:false,message:String(e&&e.stack||e)});return {apiFound:false,stage:'exception'};}"
    "})()";
}

- (void)sx244_scheduleProfileEntryRecoveryForWebView:(WKWebView *)webView {
    if(![webView isKindOfClass:WKWebView.class])return;
    NSString *probe=[self sx244_profileEntryRecoveryScript];
    if(probe.length==0)return;

    [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery244 scheduled"
                                 detail:@"delays=0,0.75,2.0,4.5"
                                    url:webView.URL];

    __weak WKWebView *weakWebView=webView;
    for(NSNumber *delay in @[@0.0,@0.75,@2.0,@4.5]){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            WKWebView *strongWebView=weakWebView;
            if(!strongWebView)return;
            [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery244 evaluate"
                                         detail:[NSString stringWithFormat:@"delay=%.2f",delay.doubleValue]
                                            url:strongWebView.URL];
            [strongWebView evaluateJavaScript:probe completionHandler:^(id result,NSError *error){
                if(error){
                    [[DiagnosticsStore shared] addError:@"Internal profile API profile-entry recovery244 evaluate failed" error:error url:strongWebView.URL];
                    return;
                }
                [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery244 returned"
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
        [self sx244_scheduleProfileEntryRecoveryForWebView:webView];
    }

    [self sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:drawer];
}

@end
