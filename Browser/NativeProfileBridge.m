#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController (NativeProfileBridge)
@end

@implementation BrowserViewController (NativeProfileBridge)

- (NSString *)sx_profileJSONLiteral:(NSString *)value {
    NSData *data=[NSJSONSerialization dataWithJSONObject:@[value?:@""] options:0 error:nil];
    NSString *array=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:@"[\"\"]";
    if(array.length>=2)return [array substringWithRange:NSMakeRange(1,array.length-2)];
    return @"\"\"";
}

- (void)sx_presentNativeProfile:(NSDictionary *)profileData {
    NativeProfileViewController *profile=[NativeProfileViewController new];
    profile.profileData=profileData?:@{};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:profile];
    nav.modalPresentationStyle=UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer {
    NSDictionary *base=[drawer.profileData isKindOfClass:NSDictionary.class]?drawer.profileData:@{};
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    if(![webView isKindOfClass:WKWebView.class]){ [self sx_presentNativeProfile:base]; return; }

    NSDictionary *probe=[base[@"followerProbe"] isKindOfClass:NSDictionary.class]?base[@"followerProbe"]:@{};
    NSString *userId=[probe[@"currentUserId"] isKindOfClass:NSString.class]?probe[@"currentUserId"]:@"";
    NSString *handle=[base[@"handle"] isKindOfClass:NSString.class]?base[@"handle"]:@"";
    NSString *screenName=[handle hasPrefix:@"@"]?[handle substringFromIndex:1]:handle;
    NSString *uidLiteral=[self sx_profileJSONLiteral:userId];
    NSString *screenLiteral=[self sx_profileJSONLiteral:screenName];

    NSString *script=[NSString stringWithFormat:@"(function(){var uid=%@,screen=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=f.dependencies&&f.dependencies.firstContext;for(var i=0;c&&i<12;i++,c=c.next){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}}}return null;}function val(o,k){try{var v=o&&o[k];return(typeof v==='string'||typeof v==='number')?v:'';}catch(e){return '';}}var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {};var state;try{state=store.getState();}catch(e){return {};}var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;if(!map||typeof map!=='object')return {};var entity=(uid&&map[uid])?map[uid]:null;if(!entity&&screen){var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]];var legacy=e&&e.legacy;if(val(e,'screen_name')===screen||val(legacy,'screen_name')===screen){entity=e;break;}}}if(!entity)return {};var legacy=(entity.legacy&&typeof entity.legacy==='object')?entity.legacy:entity;if(!uid)uid=String(val(entity,'rest_id')||val(legacy,'id_str')||val(legacy,'user_id_str')||'');var avatar=val(legacy,'profile_image_url_https')||val(entity,'profile_image_url_https');if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');var tweetRoot=state&&state.entities&&state.entities.tweets;var tweetMap=tweetRoot&&tweetRoot.entities&&typeof tweetRoot.entities==='object'?tweetRoot.entities:null;var posts=[];var tweetEntityCount=0;if(tweetMap){var tkeys=Object.keys(tweetMap);tweetEntityCount=tkeys.length;for(var ti=0;ti<tkeys.length;ti++){var t=tweetMap[tkeys[ti]];if(!t||typeof t!=='object')continue;var tl=(t.legacy&&typeof t.legacy==='object')?t.legacy:t;var owner=String(val(tl,'user_id_str')||val(tl,'user_id')||val(t,'user_id_str')||val(t,'user_id')||'');if(uid&&owner!==String(uid))continue;var text=String(val(tl,'full_text')||val(tl,'text')||val(t,'full_text')||val(t,'text')||'');if(!text)continue;var isRetweet=!!(tl.retweeted_status_id_str||t.retweeted_status_result||tl.retweeted_status_result||/^RT @/.test(text));if(isRetweet)continue;var mediaURL='';var ext=tl.extended_entities&&Array.isArray(tl.extended_entities.media)?tl.extended_entities.media:null;var med=ext&&ext.length?ext:(tl.entities&&Array.isArray(tl.entities.media)?tl.entities.media:null);if(med&&med.length){var m=med[0];mediaURL=String(val(m,'media_url_https')||val(m,'media_url')||'');}posts.push({id:String(val(t,'rest_id')||val(tl,'id_str')||tkeys[ti]),text:text,createdAt:String(val(tl,'created_at')||val(t,'created_at')||''),mediaURL:mediaURL,hasImage:mediaURL.length>0});}}posts.sort(function(a,b){var ad=Date.parse(a.createdAt)||0,bd=Date.parse(b.createdAt)||0;if(ad!==bd)return bd-ad;return a.id<b.id?1:(a.id>b.id?-1:0);});if(posts.length>20)posts=posts.slice(0,20);return {name:String(val(legacy,'name')||val(entity,'name')||''),handle:(val(legacy,'screen_name')||val(entity,'screen_name'))?'@'+String(val(legacy,'screen_name')||val(entity,'screen_name')):'',bio:String(val(legacy,'description')||val(entity,'description')||''),avatarURL:String(avatar||''),bannerURL:String(val(legacy,'profile_banner_url')||val(entity,'profile_banner_url')||''),following:String(val(legacy,'friends_count')||val(entity,'friends_count')||''),followers:String(val(legacy,'followers_count')||val(entity,'followers_count')||''),posts:posts,postProbe:{tweetEntityCount:tweetEntityCount,matchedPosts:posts.length,userId:String(uid||'')}};})()",uidLiteral,screenLiteral];

    __weak typeof(self) weakSelf=self;
    [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf; if(!self)return;
        NSMutableDictionary *merged=[base mutableCopy];
        if(!error&&[result isKindOfClass:NSDictionary.class]){
            NSDictionary *dict=(NSDictionary *)result;
            [dict enumerateKeysAndObjectsUsingBlock:^(id key,id obj,BOOL *stop){
                if([obj isKindOfClass:NSString.class]&&[(NSString *)obj length]>0)merged[key]=obj;
            }];
            if([dict[@"posts"] isKindOfClass:NSArray.class])merged[@"posts"]=dict[@"posts"];
            if([dict[@"postProbe"] isKindOfClass:NSDictionary.class]){
                merged[@"postProbe"]=dict[@"postProbe"];
                NSDictionary *postProbe=dict[@"postProbe"];
                NSNumber *entities=[postProbe[@"tweetEntityCount"] isKindOfClass:NSNumber.class]?postProbe[@"tweetEntityCount"]:@0;
                NSNumber *matched=[postProbe[@"matchedPosts"] isKindOfClass:NSNumber.class]?postProbe[@"matchedPosts"]:@0;
                [[DiagnosticsStore shared] addEvent:@"Native profile post cache" detail:[NSString stringWithFormat:@"tweetEntities=%@ matchedPosts=%@",entities,matched] url:webView.URL];
            }
        } else if(error) {
            [[DiagnosticsStore shared] addError:@"Native profile extraction failed" error:error url:webView.URL];
        }
        dispatch_async(dispatch_get_main_queue(),^{ [self sx_presentNativeProfile:merged]; });
    }];
}

@end
