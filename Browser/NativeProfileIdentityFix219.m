#import "BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileIdentityFix219Private)
- (NSString *)sx_profileJSONLiteral:(NSString *)value;
@end

@implementation BrowserViewController (NativeProfileIdentityFix219)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL targetSEL=@selector(sx217_profileRefreshScriptForUserId:screenName:);
        SEL replacementSEL=@selector(sx219_profileRefreshScriptForUserId:screenName:);
        Method target=class_getInstanceMethod(self,targetSEL);
        Method replacement=class_getInstanceMethod(self,replacementSEL);
        if(target&&replacement){
            class_replaceMethod(self,targetSEL,method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (NSString *)sx219_profileRefreshScriptForUserId:(NSString *)userId screenName:(NSString *)screenName {
    NSString *uid=[self sx_profileJSONLiteral:userId?:@""];
    NSString *screen=[self sx_profileJSONLiteral:screenName?:@""];
    return [NSString stringWithFormat:@"(function(){"
        "var uid=%@,screen=%@;"
        "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
        "function asStore(v){if(!v||typeof v!=='object')return null;var s=v;try{var d=Object.getOwnPropertyDescriptor(v,'store');if(d&&Object.prototype.hasOwnProperty.call(d,'value')&&d.value&&typeof d.value==='object')s=d.value;}catch(_){}try{return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}catch(_){return null;}}"
        "function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<90;d++,f=f.return){var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){}for(var i=0;c&&i<20;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(_){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(_){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(_){break;}}}return null;}"
        "var p=document.querySelector('[data-testid=DashButton_ProfileIcon_Link]');"
        "if(p){var href=p.getAttribute('href')||'';if(!href&&p.closest){var a=p.closest('a[href]');href=a?(a.getAttribute('href')||''):'';}var domScreen=(/^\\/[A-Za-z0-9_]+$/.test(href))?href.slice(1):'';if(domScreen)screen=domScreen;}"
        "var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {};"
        "var state=null;try{state=store.getState();}catch(_){return {};}"
        "var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;if(!map)return {};"
        "var entity=null,keys=[];try{keys=Object.keys(map);}catch(_){}"
        "if(screen){for(var i=0;i<keys.length;i++){var e=map[keys[i]],l=e&&e.legacy;var sn=(l&&l.screen_name)||(e&&e.screen_name)||'';if(sn===screen){entity=e;uid=String((e&&e.rest_id)||(l&&l.id_str)||keys[i]||uid||'');break;}}}"
        "if(!entity&&uid&&map[uid])entity=map[uid];"
        "if(!entity)return {};"
        "var l=entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;"
        "var resolvedId=String((entity&&entity.rest_id)||(l&&l.id_str)||uid||'');"
        "var sn=(l&&l.screen_name)||(entity&&entity.screen_name)||screen||'';"
        "var avatar=(l&&l.profile_image_url_https)||(entity&&entity.profile_image_url_https)||'';if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');"
        "var verification=entity&&entity.verification&&typeof entity.verification==='object'?entity.verification:null;return {name:String((l&&l.name)||(entity&&entity.name)||''),handle:sn?'@'+sn:'',bio:String((l&&l.description)||(entity&&entity.description)||''),avatarURL:String(avatar||''),bannerURL:String((l&&l.profile_banner_url)||(entity&&entity.profile_banner_url)||''),following:l&&l.friends_count!=null?String(l.friends_count):'',followers:l&&l.followers_count!=null?String(l.followers_count):'',createdAt:String((l&&l.created_at)||(entity&&entity.created_at)||''),verified:!!((entity&&entity.is_blue_verified)||(entity&&entity.verified)||(l&&l.verified)||(verification&&(verification.verified||(typeof verification.verified_type==='string'&&verification.verified_type.length)))),protected:!!((l&&l.protected)||(entity&&entity.protected)),userId:resolvedId};"
    "})()",uid,screen];
}

@end
