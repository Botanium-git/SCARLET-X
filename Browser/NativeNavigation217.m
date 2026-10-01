#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeNavigation217Private)
- (void)presentNativeDrawerWithProfileData:(NSDictionary *)profileData;
- (NSString *)sx_profileJSONLiteral:(NSString *)value;
- (void)sx_startOfficialProfilePostLoadForScreenName:(NSString *)screenName
                                              userId:(NSString *)userId
                                                base:(NSDictionary *)base
                                             profile:(NativeProfileViewController *)profile
                                       sourceWebView:(WKWebView *)sourceWebView;
@end

@interface NativeDrawerViewController (NativeNavigation217Private)
- (UIView *)buildProfileHeader;
@end

static char SX217DrawerCacheKey;

@implementation BrowserViewController (NativeNavigation217)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method openOriginal=class_getInstanceMethod(self,@selector(openNativeDrawer));
        Method openReplacement=class_getInstanceMethod(self,@selector(sx217_openNativeDrawer));
        if(openOriginal&&openReplacement)method_exchangeImplementations(openOriginal,openReplacement);

        Method profileOriginal=class_getInstanceMethod(self,@selector(nativeDrawerDidSelectNativeProfile:));
        Method profileReplacement=class_getInstanceMethod(self,@selector(sx217_nativeDrawerDidSelectNativeProfile:));
        if(profileOriginal&&profileReplacement)method_exchangeImplementations(profileOriginal,profileReplacement);

        Method finishOriginal=class_getInstanceMethod(self,@selector(webView:didFinishNavigation:));
        Method finishReplacement=class_getInstanceMethod(self,@selector(sx217_webView:didFinishNavigation:));
        if(finishOriginal&&finishReplacement)method_exchangeImplementations(finishOriginal,finishReplacement);
    });
}

- (WKWebView *)sx217_webView {
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    return [webView isKindOfClass:WKWebView.class]?webView:nil;
}

- (NSString *)sx217_fastDrawerScript {
    return @"(function(){"
    "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
    "function asStore(v){if(!v||typeof v!=='object')return null;var s=v;try{var d=Object.getOwnPropertyDescriptor(v,'store');if(d&&Object.prototype.hasOwnProperty.call(d,'value')&&d.value&&typeof d.value==='object')s=d.value;}catch(_){}try{return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}catch(_){return null;}}"
    "function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<14;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}"
    "function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>4)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length&&x.length<1000){found=x;return;}}catch(_){}var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var i=0;i<Math.min(ks.length,55);i++){var x;try{x=v[ks[i]];}catch(_){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}"
    "var p=document.querySelector('[data-testid=DashButton_ProfileIcon_Link]');var img=p&&p.querySelector('img');var label=p?(p.getAttribute('aria-label')||''):'';var labelName=label.replace(/^プロフィールメニュー\\s*/,'');var href=p?(p.getAttribute('href')||''):'';if(!href&&p&&p.closest){var a=p.closest('a[href]');href=a?(a.getAttribute('href')||''):'';}var currentScreen=(/^\\/[A-Za-z0-9_]+$/.test(href))?href.slice(1):'';"
    "var fallback={source:'fast-dom',avatarURL:img?(img.currentSrc||img.src||''):'',name:labelName,handle:currentScreen?'@'+currentScreen:'',following:'',followers:'',accounts:[],followerProbe:{currentScreen:currentScreen,currentUserId:''}};"
    "var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return fallback;var state=null;try{state=store.getState();}catch(_){return fallback;}"
    "var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name'),name:firstString(u,'name'),avatarURL:firstString(u,'avatar_image_url')||firstString(u,'profile_image_url_https')};}).filter(function(u){return !!(u.screenName||u.name||u.avatarURL);});"
    "var current=null;if(currentScreen)current=mapped.find(function(u){return u.screenName===currentScreen;})||null;if(!current&&labelName){var same=mapped.filter(function(u){return u.name===labelName;});if(same.length===1)current=same[0];}"
    "var accounts=mapped.filter(function(u){return !current||u!==current;}).map(function(u){return {handle:u.screenName?'@'+u.screenName:'',avatarURL:u.avatarURL||''};});"
    "var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;var currentId=current&&current.userId?current.userId:'';var screen=(current&&current.screenName)||currentScreen;var entity=(map&&currentId&&map[currentId])?map[currentId]:null;if(!entity&&map&&screen){try{var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]],l=e&&e.legacy;var sn=(l&&l.screen_name)||e&&e.screen_name;if(sn===screen){entity=e;currentId=String((e&&e.rest_id)||(l&&l.id_str)||currentId||'');break;}}}catch(_){}}"
    "var legacy=entity&&entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;var following=legacy&&legacy.friends_count!=null?String(legacy.friends_count):'';var followers=legacy&&legacy.followers_count!=null?String(legacy.followers_count):'';var avatar=(current&&current.avatarURL)||(legacy&&legacy.profile_image_url_https)||(img?(img.currentSrc||img.src||''):'');if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');"
    "return {source:'fast-redux',avatarURL:avatar||'',name:(current&&current.name)||(legacy&&legacy.name)||labelName||'',handle:screen?'@'+screen:'',following:following,followers:followers,accounts:accounts,followerProbe:{currentScreen:screen||'',currentUserId:currentId||'',counts:{friends_count:legacy&&legacy.friends_count,followers_count:legacy&&legacy.followers_count}}};"
    "})()";
}

- (void)sx217_applyDrawerCache:(NSDictionary *)data {
    if(![data isKindOfClass:NSDictionary.class])return;
    objc_setAssociatedObject(self,&SX217DrawerCacheKey,[data copy],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NativeDrawerViewController *drawer=nil;
    @try { drawer=[self valueForKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
    if(![drawer isKindOfClass:NativeDrawerViewController.class]||!drawer.parentViewController)return;
    drawer.profileData=data;
    UITableView *table=nil;
    @try { table=[drawer valueForKey:@"tableView"]; } @catch(__unused NSException *exception) {}
    if([table isKindOfClass:UITableView.class])table.tableHeaderView=[drawer buildProfileHeader];
}

- (void)sx217_prefetchDrawerData {
    WKWebView *webView=[self sx217_webView];
    if(!webView)return;
    NSString *script=[self sx217_fastDrawerScript];
    __weak typeof(self) weakSelf=self;
    [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;
        if(error){[[DiagnosticsStore shared] addError:@"Native drawer fast prefetch failed" error:error url:webView.URL];return;}
        if([result isKindOfClass:NSDictionary.class])dispatch_async(dispatch_get_main_queue(),^{[self sx217_applyDrawerCache:result];});
    }];
}

- (void)sx217_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self sx217_webView:webView didFinishNavigation:navigation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.15*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self sx217_prefetchDrawerData];});
}

- (void)sx217_openNativeDrawer {
    NativeDrawerViewController *existing=nil;
    @try { existing=[self valueForKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
    if([existing isKindOfClass:NativeDrawerViewController.class]&&existing.parentViewController)return;

    NSDictionary *cached=objc_getAssociatedObject(self,&SX217DrawerCacheKey);
    if([cached isKindOfClass:NSDictionary.class]&&cached.count){
        [[DiagnosticsStore shared] addEvent:@"Native drawer fast path" detail:@"presenting cached profile data immediately" url:[self sx217_webView].URL];
        [self presentNativeDrawerWithProfileData:cached];
        [self sx217_prefetchDrawerData];
        return;
    }

    WKWebView *webView=[self sx217_webView];
    if(!webView){[self presentNativeDrawerWithProfileData:@{}];return;}
    NSString *script=@"(function(){var p=document.querySelector('[data-testid=DashButton_ProfileIcon_Link]');var img=p&&p.querySelector('img');var label=p?(p.getAttribute('aria-label')||''):'';var name=label.replace(/^プロフィールメニュー\\s*/,'');var href=p?(p.getAttribute('href')||''):'';if(!href&&p&&p.closest){var a=p.closest('a[href]');href=a?(a.getAttribute('href')||''):'';}var screen=(/^\\/[A-Za-z0-9_]+$/.test(href))?href.slice(1):'';return {source:'instant-dom',avatarURL:img?(img.currentSrc||img.src||''):'',name:name,handle:screen?'@'+screen:'',following:'',followers:'',accounts:[],followerProbe:{currentScreen:screen,currentUserId:''}};})()";
    __weak typeof(self) weakSelf=self;
    [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;if(!self)return;
        NSDictionary *data=[result isKindOfClass:NSDictionary.class]?result:@{};
        dispatch_async(dispatch_get_main_queue(),^{[self presentNativeDrawerWithProfileData:data];[self sx217_prefetchDrawerData];});
    }];
}

- (NativeProfileViewController *)sx217_presentProfileFromRight:(NSDictionary *)profileData {
    NativeProfileViewController *profile=[NativeProfileViewController new];
    profile.profileData=profileData?:@{};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:profile];
    nav.modalPresentationStyle=UIModalPresentationFullScreen;
    CATransition *transition=[CATransition animation];
    transition.duration=.28;
    transition.type=kCATransitionPush;
    transition.subtype=kCATransitionFromRight;
    transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.view.window.layer addAnimation:transition forKey:@"sx217-profile-in"];
    [self presentViewController:nav animated:NO completion:nil];
    return profile;
}

- (NSString *)sx217_profileRefreshScriptForUserId:(NSString *)userId screenName:(NSString *)screenName {
    NSString *uid=[self sx_profileJSONLiteral:userId?:@""];
    NSString *screen=[self sx_profileJSONLiteral:screenName?:@""];
    return [NSString stringWithFormat:@"(function(){var uid=%@,screen=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;try{return(typeof v.getState==='function'&&typeof v.dispatch==='function')?v:null;}catch(_){return null;}}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<14;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}var store=storeFromNode(document.querySelector('[data-testid=DashButton_ProfileIcon_Link]'))||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {};var state=null;try{state=store.getState();}catch(_){return {};}var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;if(!map)return {};var entity=uid&&map[uid]?map[uid]:null;if(!entity&&screen){try{var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]],l=e&&e.legacy;var sn=(l&&l.screen_name)||e&&e.screen_name;if(sn===screen){entity=e;uid=String((e&&e.rest_id)||(l&&l.id_str)||uid||'');break;}}}catch(_){}}if(!entity)return {};var l=entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;var avatar=(l&&l.profile_image_url_https)||entity.profile_image_url_https||'';if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');var sn=(l&&l.screen_name)||entity.screen_name||screen||'';return {name:String((l&&l.name)||entity.name||''),handle:sn?'@'+sn:'',bio:String((l&&l.description)||entity.description||''),avatarURL:String(avatar||''),bannerURL:String((l&&l.profile_banner_url)||entity.profile_banner_url||''),following:l&&l.friends_count!=null?String(l.friends_count):'',followers:l&&l.followers_count!=null?String(l.followers_count):'',userId:String(uid||'')};})()",uid,screen];
}

- (void)sx217_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer {
    NSDictionary *base=[drawer.profileData isKindOfClass:NSDictionary.class]?drawer.profileData:@{};
    NSMutableDictionary *initial=[base mutableCopy];
    initial[@"posts"]=@[];
    initial[@"postsLoading"]=@YES;
    NativeProfileViewController *profile=[self sx217_presentProfileFromRight:initial];

    WKWebView *webView=[self sx217_webView];
    if(!webView)return;
    NSDictionary *probe=[base[@"followerProbe"] isKindOfClass:NSDictionary.class]?base[@"followerProbe"]:@{};
    NSString *userId=[probe[@"currentUserId"] isKindOfClass:NSString.class]?probe[@"currentUserId"]:@"";
    NSString *handle=[base[@"handle"] isKindOfClass:NSString.class]?base[@"handle"]:@"";
    NSString *screenName=[handle hasPrefix:@"@"]?[handle substringFromIndex:1]:handle;
    NSString *script=[self sx217_profileRefreshScriptForUserId:userId screenName:screenName];

    __weak typeof(self) weakSelf=self;
    __weak NativeProfileViewController *weakProfile=profile;
    [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;NativeProfileViewController *profile=weakProfile;if(!self||!profile)return;
        NSMutableDictionary *merged=[initial mutableCopy];
        NSString *resolvedUserId=userId;
        NSString *resolvedScreen=screenName;
        if(!error&&[result isKindOfClass:NSDictionary.class]){
            NSDictionary *dict=result;
            [dict enumerateKeysAndObjectsUsingBlock:^(id key,id obj,BOOL *stop){if([obj isKindOfClass:NSString.class]&&[(NSString *)obj length])merged[key]=obj;}];
            NSString *rid=[dict[@"userId"] isKindOfClass:NSString.class]?dict[@"userId"]:@"";if(rid.length)resolvedUserId=rid;
            NSString *rh=[dict[@"handle"] isKindOfClass:NSString.class]?dict[@"handle"]:@"";if([rh hasPrefix:@"@"])rh=[rh substringFromIndex:1];if(rh.length)resolvedScreen=rh;
        } else if(error) {
            [[DiagnosticsStore shared] addError:@"Native profile background refresh failed" error:error url:webView.URL];
        }
        dispatch_async(dispatch_get_main_queue(),^{[profile applyProfileData:merged];});
        [self sx_startOfficialProfilePostLoadForScreenName:resolvedScreen userId:resolvedUserId base:merged profile:profile sourceWebView:webView];
    }];
}

@end
