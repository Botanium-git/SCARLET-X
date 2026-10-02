#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSString * const SX218DrawerCacheDefaultsKey = @"ScarletXDrawerProfileCacheV2";

@interface BrowserViewController (NativeNavigation218Private)
- (void)presentNativeDrawerWithProfileData:(NSDictionary *)profileData;
- (NSString *)sx_profileJSONLiteral:(NSString *)value;
- (void)sx217_prefetchDrawerData;
- (WKWebView *)sx217_webView;
@end

@interface NativeDrawerViewController (NativeNavigation218Private)
- (UIView *)buildProfileHeader;
@end

@implementation BrowserViewController (NativeNavigation218)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls=self;
        SEL pairs[][2] = {
            {@selector(openNativeDrawer), @selector(sx218_openNativeDrawer)},
            {@selector(sx217_fastDrawerScript), @selector(sx218_fastDrawerScript)},
            {@selector(sx217_applyDrawerCache:), @selector(sx218_applyDrawerCache:)},
            {@selector(sx217_profileRefreshScriptForUserId:screenName:), @selector(sx218_profileRefreshScriptForUserId:screenName:)},
            {@selector(sx217_presentProfileFromRight:), @selector(sx218_presentProfileFromRight:)}
        };
        for (NSUInteger i=0;i<sizeof(pairs)/sizeof(pairs[0]);i++) {
            Method target=class_getInstanceMethod(cls,pairs[i][0]);
            Method replacement=class_getInstanceMethod(cls,pairs[i][1]);
            if(target&&replacement) class_replaceMethod(cls,pairs[i][0],method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (NSDictionary *)sx218_persistedDrawerData {
    NSData *data=[[NSUserDefaults standardUserDefaults] objectForKey:SX218DrawerCacheDefaultsKey];
    if(![data isKindOfClass:NSData.class])return nil;
    id object=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class]?object:nil;
}

- (void)sx218_openNativeDrawer {
    NativeDrawerViewController *existing=nil;
    @try { existing=[self valueForKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
    if([existing isKindOfClass:NativeDrawerViewController.class]&&existing.parentViewController)return;

    NSDictionary *cached=[self sx218_persistedDrawerData];
    [[DiagnosticsStore shared] addEvent:@"Native drawer instant path" detail:cached.count?@"present persisted cache immediately":@"present immediately without waiting for JavaScript" url:[self sx217_webView].URL];
    [self presentNativeDrawerWithProfileData:cached?:@{}];
    [self sx217_prefetchDrawerData];
}

- (NSString *)sx218_fastDrawerScript {
    return @"(function(){"
    "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
    "function asStore(v){if(!v||typeof v!=='object')return null;var s=v;try{var d=Object.getOwnPropertyDescriptor(v,'store');if(d&&Object.prototype.hasOwnProperty.call(d,'value')&&d.value&&typeof d.value==='object')s=d.value;}catch(_){}try{return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}catch(_){return null;}}"
    "function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<90;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<20;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}"
    "function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>4)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length&&x.length<1000){found=x;return;}}catch(_){}var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var i=0;i<Math.min(ks.length,60);i++){var x;try{x=v[ks[i]];}catch(_){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}"
    "var p=document.querySelector('[data-testid=DashButton_ProfileIcon_Link]');var img=p&&p.querySelector('img');var label=p?(p.getAttribute('aria-label')||''):'';var labelName=label.replace(/^プロフィールメニュー\\s*/,'');var href=p?(p.getAttribute('href')||''):'';if(!href&&p&&p.closest){var a=p.closest('a[href]');href=a?(a.getAttribute('href')||''):'';}var currentScreen=(/^\\/[A-Za-z0-9_]+$/.test(href))?href.slice(1):'';"
    "var fallback={source:'fast-dom',avatarURL:img?(img.currentSrc||img.src||''):'',bannerURL:'',bio:'',name:labelName,handle:currentScreen?'@'+currentScreen:'',following:'',followers:'',accounts:[],followerProbe:{currentScreen:currentScreen,currentUserId:''}};"
    "var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return fallback;var state=null;try{state=store.getState();}catch(_){return fallback;}"
    "var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name'),name:firstString(u,'name'),avatarURL:firstString(u,'avatar_image_url')||firstString(u,'profile_image_url_https')};}).filter(function(u){return !!(u.screenName||u.name||u.avatarURL);});"
    "var current=null;if(currentScreen)current=mapped.find(function(u){return u.screenName===currentScreen;})||null;if(!current&&labelName){var same=mapped.filter(function(u){return u.name===labelName;});if(same.length===1)current=same[0];}"
    "var accounts=mapped.filter(function(u){return !current||u!==current;}).map(function(u){return {handle:u.screenName?'@'+u.screenName:'',avatarURL:u.avatarURL||''};});"
    "var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;var currentId=current&&current.userId?current.userId:'';var screen=(current&&current.screenName)||currentScreen;var entity=(map&&currentId&&map[currentId])?map[currentId]:null;if(!entity&&map&&screen){try{var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]],l=e&&e.legacy;var sn=(l&&l.screen_name)||e&&e.screen_name;if(sn===screen){entity=e;currentId=String((e&&e.rest_id)||(l&&l.id_str)||currentId||'');break;}}}catch(_){}}"
    "var l=entity&&entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;var following=l&&l.friends_count!=null?String(l.friends_count):'';var followers=l&&l.followers_count!=null?String(l.followers_count):'';var avatar=(current&&current.avatarURL)||(l&&l.profile_image_url_https)||(img?(img.currentSrc||img.src||''):'');if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');"
    "return {source:'fast-redux',avatarURL:String(avatar||''),bannerURL:String((l&&l.profile_banner_url)||(entity&&entity.profile_banner_url)||''),bio:String((l&&l.description)||(entity&&entity.description)||''),name:String((current&&current.name)||(l&&l.name)||(entity&&entity.name)||labelName||''),handle:screen?'@'+screen:'',following:following,followers:followers,accounts:accounts,followerProbe:{currentScreen:screen||'',currentUserId:currentId||'',counts:{friends_count:l&&l.friends_count,followers_count:l&&l.followers_count}}};"
    "})()";
}

- (void)sx218_applyDrawerCache:(NSDictionary *)data {
    if(![data isKindOfClass:NSDictionary.class])return;
    NSData *json=[NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    if(json){[[NSUserDefaults standardUserDefaults] setObject:json forKey:SX218DrawerCacheDefaultsKey];}

    NativeDrawerViewController *drawer=nil;
    @try { drawer=[self valueForKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
    if(![drawer isKindOfClass:NativeDrawerViewController.class]||!drawer.parentViewController)return;
    drawer.profileData=data;
    UITableView *table=nil;
    @try { table=[drawer valueForKey:@"tableView"]; } @catch(__unused NSException *exception) {}
    if([table isKindOfClass:UITableView.class])table.tableHeaderView=[drawer buildProfileHeader];
}

- (NSString *)sx218_profileRefreshScriptForUserId:(NSString *)userId screenName:(NSString *)screenName {
    NSString *uid=[self sx_profileJSONLiteral:userId?:@""];
    NSString *screen=[self sx_profileJSONLiteral:screenName?:@""];
    return [NSString stringWithFormat:@"(function(){var uid=%@,screen=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=v;try{var d=Object.getOwnPropertyDescriptor(v,'store');if(d&&Object.prototype.hasOwnProperty.call(d,'value')&&d.value&&typeof d.value==='object')s=d.value;}catch(_){}try{return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}catch(_){return null;}}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<90;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<20;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}var store=storeFromNode(document.querySelector('[data-testid=DashButton_ProfileIcon_Link]'))||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {};var state=null;try{state=store.getState();}catch(_){return {};}var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;if(!map)return {};var entity=uid&&map[uid]?map[uid]:null;if(!entity&&screen){try{var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]],l=e&&e.legacy;var sn=(l&&l.screen_name)||e&&e.screen_name;if(sn===screen){entity=e;uid=String((e&&e.rest_id)||(l&&l.id_str)||uid||'');break;}}}catch(_){}}if(!entity)return {};var l=entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;var avatar=(l&&l.profile_image_url_https)||entity.profile_image_url_https||'';if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');var sn=(l&&l.screen_name)||entity.screen_name||screen||'';return {name:String((l&&l.name)||entity.name||''),handle:sn?'@'+sn:'',bio:String((l&&l.description)||entity.description||''),avatarURL:String(avatar||''),bannerURL:String((l&&l.profile_banner_url)||entity.profile_banner_url||''),following:l&&l.friends_count!=null?String(l.friends_count):'',followers:l&&l.followers_count!=null?String(l.followers_count):'',userId:String(uid||'')};})()",uid,screen];
}

- (NativeProfileViewController *)sx218_presentProfileFromRight:(NSDictionary *)profileData {
    NativeProfileViewController *profile=[NativeProfileViewController new];
    profile.profileData=profileData?:@{};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:profile];
    nav.modalPresentationStyle=UIModalPresentationFullScreen;
    CATransition *transition=[CATransition animation];
    transition.duration=.20;
    transition.type=kCATransitionPush;
    transition.subtype=kCATransitionFromRight;
    transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.view.window.layer addAnimation:transition forKey:@"sx218-profile-in"];
    [self presentViewController:nav animated:NO completion:nil];
    return profile;
}

@end
