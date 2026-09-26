#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (AccountSwitchProbeOriginal)
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path;
@end

@implementation BrowserViewController (AccountSwitchProbe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(nativeDrawer:didSelectPath:));
        Method probe=class_getInstanceMethod(self,@selector(sx_accountProbe_nativeDrawer:didSelectPath:));
        if(original&&probe)method_exchangeImplementations(original,probe);
    });
}

- (void)sx_accountProbe_nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    if(![path hasPrefix:@"/__scarletx_account_probe"]){
        [self sx_accountProbe_nativeDrawer:drawer didSelectPath:path];
        return;
    }

    NSURLComponents *components=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *targetScreen=@"",*targetAvatar=@"";
    for(NSURLQueryItem *item in components.queryItems){
        if([item.name isEqual:@"screen_name"]&&item.value.length)targetScreen=item.value;
        else if([item.name isEqual:@"avatar"]&&item.value.length)targetAvatar=item.value;
    }
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![webView isKindOfClass:WKWebView.class]){
        [[DiagnosticsStore shared] addEvent:@"Account switch diagnostic failed" detail:@"webView unavailable" url:nil];
        return;
    }

    NSDictionary *input=@{@"screenName":targetScreen?:@"",@"avatarURL":targetAvatar?:@""};
    NSData *inputData=[NSJSONSerialization dataWithJSONObject:input options:0 error:nil];
    NSString *inputJSON=inputData?[[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding]:@"{}";
    [[DiagnosticsStore shared] addEvent:@"Account switch diagnostic start" detail:[NSString stringWithFormat:@"target=@%@",targetScreen] url:webView.URL];

    NSString *script=[NSString stringWithFormat:@"(function(){var input=%@,targetScreen=input.screenName||'',targetAvatar=input.avatarURL||'',done=false,observer=null,timer=null;function send(stage,payload){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch-diagnostic '+stage+' '+JSON.stringify(payload||{})});}catch(_){}}function textOf(el){return ((el&&(el.innerText||el.textContent))||'').trim();}function attrs(el){return {tag:(el&&el.tagName)||'',role:(el&&el.getAttribute&&el.getAttribute('role'))||'',testid:(el&&el.getAttribute&&el.getAttribute('data-testid'))||'',aria:(el&&el.getAttribute&&el.getAttribute('aria-label'))||'',text:textOf(el).slice(0,500),href:(el&&el.getAttribute&&el.getAttribute('href'))||''};}function images(el){return Array.from(el&&el.querySelectorAll?el.querySelectorAll('img'):[]).slice(0,6).map(function(i){return {src:i.currentSrc||i.src||'',alt:i.alt||'',testid:i.getAttribute('data-testid')||''};});}function reactProps(el){var out={key:'',keys:[],strings:{}};if(!el)return out;var ks=[];try{ks=Object.keys(el);}catch(e){}var rk=ks.find(function(k){return k.indexOf('__reactProps$')===0;});if(!rk)return out;out.key=rk;var p=null;try{p=el[rk];}catch(e){}if(!p||typeof p!=='object')return out;try{out.keys=Object.keys(p).slice(0,60);}catch(e){}out.keys.forEach(function(k){var v;try{v=p[k];}catch(e){return;}if(typeof v==='string'&&v.length<1000)out.strings[k]=v;else if(typeof v==='number'||typeof v==='boolean')out.strings[k]=v;});return out;}function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return (s&&typeof s.getState==='function'&&typeof s.subscribe==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(e){}for(var i=0;c&&i<10;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(e){break;}}var direct=null;try{direct=asStore(f.memoizedProps);}catch(e){}if(direct)return direct;}return null;}function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>5)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length&&x.length<1000){found=x;return;}}catch(e){}var ks=[];try{ks=Object.keys(v);}catch(e){return;}for(var i=0;i<Math.min(ks.length,70);i++){var x;try{x=v[ks[i]];}catch(e){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}function reduxSnapshot(profile){var store=storeFromNode(profile)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {found:false};var state=null;try{state=store.getState();}catch(e){return {found:true,error:String(e)};}var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name'),name:firstString(u,'name'),avatarURL:firstString(u,'avatar_image_url')||firstString(u,'profile_image_url_https')};});var target=mapped.find(function(u){return u.screenName===targetScreen;})||null;var href=profile?(profile.getAttribute('href')||''):'';var currentScreen=(href.charAt(0)==='/'&&href.indexOf('/',1)<0)?href.slice(1):'';var current=mapped.find(function(u){return u.screenName===currentScreen;})||null;return {found:true,currentScreen:currentScreen,current:current,target:target,users:mapped};}function candidates(){return Array.from(document.querySelectorAll('button')).filter(function(b){var a=b.getAttribute('aria-label')||'';return a.slice(-6)==='に切り替える';}).slice(0,10).map(function(b){var chain=[],n=b;for(var d=0;n&&d<5;d++,n=n.parentElement)chain.push({depth:d,attrs:attrs(n),images:images(n)});return {button:attrs(b),images:images(b),reactProps:reactProps(b),chain:chain,html:(b.outerHTML||'').slice(0,5000)};});}function finish(stage,profile){if(done)return;done=true;if(observer)observer.disconnect();if(timer)clearTimeout(timer);send(stage,{target:{screenName:targetScreen,avatarURL:targetAvatar},url:location.href,redux:reduxSnapshot(profile),switchCandidates:candidates(),menus:Array.from(document.querySelectorAll('[role=menu],[role=dialog]')).slice(-4).map(function(el){return {attrs:attrs(el),images:images(el),html:(el.outerHTML||'').slice(0,5000)};})});window.__scarletXNativeBypass=false;}var profile=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');if(!profile){send('profile-not-found',{target:{screenName:targetScreen,avatarURL:targetAvatar},url:location.href});return null;}send('begin',{target:{screenName:targetScreen,avatarURL:targetAvatar},redux:reduxSnapshot(profile),url:location.href});function inspect(){var c=candidates();if(c.length){finish('captured',profile);return true;}return false;}observer=new MutationObserver(function(){inspect();});observer.observe(document.documentElement||document.body,{childList:true,subtree:true,attributes:true});window.__scarletXNativeBypass=true;try{profile.click();send('profile-clicked',{targetScreen:targetScreen});}catch(e){window.__scarletXNativeBypass=false;send('profile-click-failed',{error:String(e),targetScreen:targetScreen});return null;}setTimeout(inspect,120);setTimeout(inspect,350);setTimeout(inspect,700);setTimeout(inspect,1400);timer=setTimeout(function(){finish('timeout',profile);},2600);return null;})()",inputJSON];

    [webView evaluateJavaScript:script completionHandler:^(__unused id result,NSError *error){
        if(error)[[DiagnosticsStore shared] addError:@"Account switch diagnostic injection failed" error:error url:webView.URL];
    }];
}

@end
