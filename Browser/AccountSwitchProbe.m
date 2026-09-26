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
    if(![path hasPrefix:@"/__scarletx_account_probe"]){ [self sx_switch_nativeDrawer:drawer didSelectPath:path]; return; }
    if([objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;

    NSURLComponents *c=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *target=@"";
    for(NSURLQueryItem *q in c.queryItems)if([q.name isEqual:@"screen_name"])target=q.value?:@"";
    if(!target.length)return;

    WKWebView *web=nil;
    @try { web=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![web isKindOfClass:WKWebView.class])return;

    objc_setAssociatedObject(self,&SXSwitchingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[DiagnosticsStore shared] addEvent:@"Direct account switch start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    NSString *script=[NSString stringWithFormat:
        @"(async function(){var target='%@';"
         "function send(stage,data){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'direct-account-switch '+stage+' '+JSON.stringify(data||{})});}catch(_){}}"
         "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
         "function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return (s&&typeof s.getState==='function'&&typeof s.subscribe==='function'&&typeof s.dispatch==='function')?s:null;}"
         "function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(e){}for(var i=0;c&&i<10;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(e){break;}}}return null;}"
         "function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>5)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length){found=x;return;}}catch(e){}var ks=[];try{ks=Object.keys(v);}catch(e){return;}for(var i=0;i<Math.min(ks.length,70);i++){var x;try{x=v[ks[i]];}catch(e){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}"
         "var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');"
         "var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);"
         "if(!store){send('no-store',{target:target});return {ok:false,reason:'no-store'};}"
         "var state=null;try{state=store.getState();}catch(e){send('state-error',{error:String(e)});return {ok:false,reason:'state-error'};}"
         "var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];"
         "var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name')};});"
         "var hit=mapped.find(function(u){return u.screenName===target;});"
         "if(!hit||!hit.userId){send('target-missing',{target:target,users:mapped});return {ok:false,reason:'target-missing'};}"
         "send('request',{target:target,userId:hit.userId,url:location.href});"
         "try{var body=new URLSearchParams({user_id:hit.userId});var resp=await fetch('https://api.x.com/1.1/account/multi/switch.json',{method:'POST',credentials:'include',headers:{'content-type':'application/x-www-form-urlencoded'},body:body});var text='';try{text=await resp.text();}catch(_){}send('response',{status:resp.status,ok:resp.ok,body:text.slice(0,500)});var success=resp.ok&&/\"status\"\\s*:\\s*\"ok\"/.test(text);if(success){send('reload-scheduled',{delayMs:350});setTimeout(function(){location.reload();},350);}return {ok:success,status:resp.status,body:text.slice(0,500),userId:hit.userId};}catch(e){send('fetch-error',{error:String(e)});return {ok:false,reason:'fetch-error',error:String(e)};}})()",escaped];

    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;
        if(error){
            [[DiagnosticsStore shared] addError:@"Direct account switch injection failed" error:error url:web.URL];
            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:result?:@{} options:0 error:nil];
        NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[result description];
        [[DiagnosticsStore shared] addEvent:@"Direct account switch result" detail:detail?:@"" url:web.URL];
        NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
        if(![dict[@"ok"] boolValue])objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}
@end
