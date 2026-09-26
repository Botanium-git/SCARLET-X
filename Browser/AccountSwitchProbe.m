#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (AccountSwitchOriginal)
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path;
@end

@implementation BrowserViewController (AccountSwitch)
static char SXSwitchingKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method a=class_getInstanceMethod(self,@selector(nativeDrawer:didSelectPath:));
        Method b=class_getInstanceMethod(self,@selector(sx_switch_nativeDrawer:didSelectPath:));
        if(a&&b)method_exchangeImplementations(a,b);
    });
}

- (void)sx_switch_nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    if(![path hasPrefix:@"/__scarletx_account_probe"]){
        [self sx_switch_nativeDrawer:drawer didSelectPath:path];
        return;
    }
    if([objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;

    NSURLComponents *c=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *target=@"";
    for(NSURLQueryItem *q in c.queryItems){
        if([q.name isEqual:@"screen_name"])target=q.value?:@"";
    }
    if(!target.length)return;

    WKWebView *web=nil;
    @try { web=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![web isKindOfClass:WKWebView.class])return;

    objc_setAssociatedObject(self,&SXSwitchingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[DiagnosticsStore shared] addEvent:@"Precise internal account switch start"
                                 detail:[NSString stringWithFormat:@"target=@%@",target]
                                    url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];

    NSString *script=[NSString stringWithFormat:
      @"(function(){var target='%@';"
       "function send(kind,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'internal-account-switch-precise '+JSON.stringify({kind:kind,target:target,href:location.href,data:data||{}})});}catch(_){}}"

       "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
       "function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return (s&&typeof s.getState==='function'&&typeof s.subscribe==='function'&&typeof s.dispatch==='function')?s:null;}"
       "function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<80;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<12;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}"

       "function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>5)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length){found=x;return;}}catch(_){}var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var i=0;i<Math.min(ks.length,80);i++){var x;try{x=v[ks[i]];}catch(_){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}"

       "function chunks(){var a=window.webpackChunk_twitter_responsive_web;return Array.isArray(a)?a:[];}"
       "function captureRequire(){var arr=chunks(),req=null;if(!arr.length)return null;try{arr.push([['sxprecise'+Date.now()+Math.random().toString(36).slice(2)],{},function(r){req=r;}]);}catch(_){}return req;}"

       "function findEndpointModule(){var arr=chunks();for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]],mo=ch[1],ks=Object.keys(mo);for(var j=0;j<ks.length;j++){var id=String(ks[j]),s='';try{s=Function.prototype.toString.call(mo[id]);}catch(_){}if(s.indexOf('account/multi/switch')>=0)return {moduleId:id,chunkIds:ids,source:s};}}return null;}"

       "function referencesModule(src,id){if(!src)return false;var e=id.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&');var pats=[new RegExp('\\\\('+e+'\\\\)'),new RegExp('[=,:]'+e+'(?:[^0-9]|$)'),new RegExp('\\\\b'+e+'\\\\b')];for(var i=0;i<pats.length;i++)if(pats[i].test(src))return true;return false;}"

       "function findCaller(endpointId){var arr=chunks(),matches=[];for(var i=0;i<arr.length;i++){var ch=arr[i];if(!Array.isArray(ch)||!ch[1]||typeof ch[1]!=='object')continue;var ids=Array.isArray(ch[0])?ch[0]:[ch[0]],mo=ch[1],ks=Object.keys(mo);for(var j=0;j<ks.length;j++){var id=String(ks[j]);if(id===String(endpointId))continue;var s='';try{s=Function.prototype.toString.call(mo[id]);}catch(_){}if(!referencesModule(s,String(endpointId)))continue;var score=0;if(s.indexOf('withEndpoint')>=0)score+=4;if(s.indexOf('location.assign')>=0||s.indexOf('window.location.assign')>=0)score+=4;if(s.indexOf('SWITCH_REQUEST')>=0)score+=3;if(s.indexOf('SWITCH_SUCCESS')>=0)score+=3;if(s.indexOf('context:\"SWITCH\"')>=0||s.indexOf(\"context:'SWITCH'\")>=0)score+=3;if(s.indexOf('multiAccount')>=0)score+=1;matches.push({moduleId:id,chunkIds:ids,score:score,source:s});}}matches.sort(function(a,b){return b.score-a.score;});return matches.length?matches[0]:null;}"

       "function findThunkExport(exp){if(!exp)return null;var c=[];if(typeof exp==='function')c.push({key:'<default>',fn:exp});try{Object.keys(exp).forEach(function(k){var v=exp[k];if(typeof v==='function')c.push({key:k,fn:v});});}catch(_){}var best=null;for(var i=0;i<c.length;i++){var s='';try{s=Function.prototype.toString.call(c[i].fn);}catch(_){}var score=0;if(s.indexOf('withEndpoint')>=0)score+=4;if(s.indexOf('location.assign')>=0||s.indexOf('window.location.assign')>=0)score+=4;if(s.indexOf('SWITCH')>=0)score+=2;if(s.indexOf('redirectUrl')>=0)score+=1;if(!best||score>best.score)best={key:c[i].key,fn:c[i].fn,source:s,score:score};}return best&&best.score>=6?best:null;}"

       "var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');"
       "var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);"
       "if(!store){send('abort',{reason:'no-store'});return {ok:false,reason:'no-store'};}"

       "var state;try{state=store.getState();}catch(e){send('abort',{reason:'state-error',error:String(e)});return {ok:false,reason:'state-error'};}"
       "var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];"
       "var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name')};});"
       "var hit=mapped.find(function(u){return u.screenName===target;});"
       "if(!hit||!hit.userId){send('abort',{reason:'target-missing',users:mapped});return {ok:false,reason:'target-missing'};}"

       "var endpoint=findEndpointModule();"
       "if(!endpoint){send('abort',{reason:'endpoint-module-missing'});return {ok:false,reason:'endpoint-module-missing'};}"

       "var caller=findCaller(endpoint.moduleId);"
       "if(!caller||caller.score<8){send('abort',{reason:'caller-module-missing-or-weak',endpointModuleId:endpoint.moduleId,caller:caller?{moduleId:caller.moduleId,score:caller.score}:null});return {ok:false,reason:'caller-module-missing-or-weak'};}"

       "var req=captureRequire();"
       "if(!req){send('abort',{reason:'no-webpack-require'});return {ok:false,reason:'no-webpack-require'};}"

       "var exp;try{exp=req(caller.moduleId);}catch(e){send('abort',{reason:'caller-require-failed',moduleId:caller.moduleId,error:String(e)});return {ok:false,reason:'caller-require-failed'};}"
       "var thunk=findThunkExport(exp);"
       "if(!thunk){send('abort',{reason:'thunk-export-missing',moduleId:caller.moduleId,score:caller.score,exportKeys:(exp&&typeof exp==='object')?Object.keys(exp).slice(0,30):[]});return {ok:false,reason:'thunk-export-missing'};}"

       "send('resolved',{endpointModuleId:endpoint.moduleId,callerModuleId:caller.moduleId,callerScore:caller.score,callerChunkIds:caller.chunkIds,exportKey:thunk.key,exportScore:thunk.score,userId:hit.userId,screenName:hit.screenName});"

       "try{"
         "var action=thunk.fn({user_id:hit.userId});"
         "if(typeof action!=='function'){send('abort',{reason:'not-a-thunk',returnedType:typeof action});return {ok:false,reason:'not-a-thunk'};}"
         "var ret=store.dispatch(action);"
         "try{Promise.resolve(ret).then(function(v){send('dispatch-resolved',{valueType:typeof v});},function(e){send('dispatch-rejected',{error:String(e)});});}catch(_){}"
         "send('dispatch-called',{returnType:typeof ret});"
         "return {ok:true,endpointModuleId:endpoint.moduleId,callerModuleId:caller.moduleId,exportKey:thunk.key,userId:hit.userId};"
       "}catch(e){send('dispatch-throw',{error:String(e)});return {ok:false,reason:'dispatch-throw',error:String(e)};}"
      "})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;

        if(error){
            [[DiagnosticsStore shared] addError:@"Precise internal account switch injection failed" error:error url:web.URL];
            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        NSData *data=nil;
        if(result && [NSJSONSerialization isValidJSONObject:result]){
            data=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        }
        NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[result description];
        [[DiagnosticsStore shared] addEvent:@"Precise internal account switch result"
                                     detail:detail?:@""
                                        url:web.URL];

        NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
        if(![dict[@"ok"] boolValue]){
            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(10.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                typeof(self) self=weakSelf;if(!self)return;
                objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            });
        }
    }];
}
@end
