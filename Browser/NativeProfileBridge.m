#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileBridge)
@end

@implementation BrowserViewController (NativeProfileBridge)

static char SXNativeProfileLoaderKey;

- (NSString *)sx_profileJSONLiteral:(NSString *)value {
    NSData *data=[NSJSONSerialization dataWithJSONObject:@[value?:@""] options:0 error:nil];
    NSString *array=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:@"[\"\"]";
    if(array.length>=2)return [array substringWithRange:NSMakeRange(1,array.length-2)];
    return @"\"\"";
}

- (NativeProfileViewController *)sx_presentNativeProfile:(NSDictionary *)profileData {
    NativeProfileViewController *profile=[NativeProfileViewController new];
    profile.profileData=profileData?:@{};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:profile];
    nav.modalPresentationStyle=UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
    return profile;
}

- (void)sx_finishProfileLoader:(WKWebView *)loader {
    if(!loader)return;
    [loader stopLoading];
    [loader removeFromSuperview];
    id current=objc_getAssociatedObject(self,&SXNativeProfileLoaderKey);
    if(current==loader)objc_setAssociatedObject(self,&SXNativeProfileLoaderKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sx_startOfficialProfilePostLoadForScreenName:(NSString *)screenName userId:(NSString *)userId base:(NSDictionary *)base profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    if(screenName.length==0||![sourceWebView isKindOfClass:WKWebView.class])return;

    WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];
    configuration.websiteDataStore=sourceWebView.configuration.websiteDataStore ?: [WKWebsiteDataStore defaultDataStore];
    WKWebView *loader=[[WKWebView alloc] initWithFrame:CGRectMake(-4,-4,2,2) configuration:configuration];
    loader.userInteractionEnabled=NO;
    loader.alpha=.01;
    if(sourceWebView.customUserAgent.length)loader.customUserAgent=sourceWebView.customUserAgent;
    [self.view addSubview:loader];

    WKWebView *previous=objc_getAssociatedObject(self,&SXNativeProfileLoaderKey);
    if([previous isKindOfClass:WKWebView.class])[self sx_finishProfileLoader:previous];
    objc_setAssociatedObject(self,&SXNativeProfileLoaderKey,loader,OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSString *escaped=[screenName stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] ?: screenName;
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://x.com/%@",escaped]];
    if(!url){ [self sx_finishProfileLoader:loader]; return; }
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    [loader loadRequest:request];

    NSString *uidLiteral=[self sx_profileJSONLiteral:userId];
    NSString *screenLiteral=[self sx_profileJSONLiteral:screenName];
    NSString *extract=[NSString stringWithFormat:@"(function(){var uid=%@,screen=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<80;d++,f=f.return){var c=f.dependencies&&f.dependencies.firstContext;for(var i=0;c&&i<12;i++,c=c.next){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}}}return null;}function val(o,k){try{var v=o&&o[k];return(typeof v==='string'||typeof v==='number')?v:'';}catch(e){return '';}}var store=storeFromNode(document.querySelector('[data-testid=\\\"primaryColumn\\\"]'))||storeFromNode(document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'))||storeFromNode(document.body);if(!store)return {ready:document.readyState,articleCount:document.querySelectorAll('article[data-testid=\\\"tweet\\\"]').length,tweetEntityCount:0,posts:[]};var state;try{state=store.getState();}catch(e){return {ready:document.readyState,articleCount:0,tweetEntityCount:0,posts:[]};}var users=state&&state.entities&&state.entities.users&&state.entities.users.entities;var entity=(uid&&users&&users[uid])?users[uid]:null;if(!entity&&users&&screen){var uks=Object.keys(users);for(var ui=0;ui<uks.length;ui++){var ue=users[uks[ui]],ul=ue&&ue.legacy;if(val(ue,'screen_name')===screen||val(ul,'screen_name')===screen){entity=ue;uid=String(val(ue,'rest_id')||val(ul,'id_str')||uid||'');break;}}}var tweetRoot=state&&state.entities&&state.entities.tweets;var tweetMap=tweetRoot&&tweetRoot.entities&&typeof tweetRoot.entities==='object'?tweetRoot.entities:null;var posts=[],tweetEntityCount=0;if(tweetMap){var tks=Object.keys(tweetMap);tweetEntityCount=tks.length;for(var ti=0;ti<tks.length;ti++){var t=tweetMap[tks[ti]];if(!t||typeof t!=='object')continue;var tl=(t.legacy&&typeof t.legacy==='object')?t.legacy:t;var owner=String(val(tl,'user_id_str')||val(tl,'user_id')||val(t,'user_id_str')||val(t,'user_id')||'');if(uid&&owner!==String(uid))continue;var text=String(val(tl,'full_text')||val(tl,'text')||val(t,'full_text')||val(t,'text')||'');if(!text)continue;var isRetweet=!!(tl.retweeted_status_id_str||t.retweeted_status_result||tl.retweeted_status_result||/^RT @/.test(text));if(isRetweet)continue;var mediaURL='';var ext=tl.extended_entities&&Array.isArray(tl.extended_entities.media)?tl.extended_entities.media:null;var med=ext&&ext.length?ext:(tl.entities&&Array.isArray(tl.entities.media)?tl.entities.media:null);if(med&&med.length){var m=med[0];mediaURL=String(val(m,'media_url_https')||val(m,'media_url')||'');}posts.push({id:String(val(t,'rest_id')||val(tl,'id_str')||tks[ti]),text:text,createdAt:String(val(tl,'created_at')||val(t,'created_at')||''),mediaURL:mediaURL,hasImage:mediaURL.length>0});}}posts.sort(function(a,b){var ad=Date.parse(a.createdAt)||0,bd=Date.parse(b.createdAt)||0;if(ad!==bd)return bd-ad;return a.id<b.id?1:(a.id>b.id?-1:0);});if(posts.length>20)posts=posts.slice(0,20);var joinedText='',domProtected=false,profileAria=[];try{var hi=document.querySelector('[data-testid=\\\"UserProfileHeader_Items\\\"]');var ht=String(hi&&hi.innerText||'');var jm=ht.match(/\\d{4}年\\d{1,2}月からXを利用しています/);if(jm&&jm[0])joinedText=jm[0];if(!joinedText){var bt=String(document.body&&document.body.innerText||'');jm=bt.match(/\\d{4}年\\d{1,2}月からXを利用しています/);if(jm&&jm[0])joinedText=jm[0];}}catch(_){}try{var un=document.querySelector('[data-testid=\\\"UserName\\\"]');if(un){var ns=un.querySelectorAll('[aria-label],svg,title');for(var ni=0;ni<ns.length&&ni<40;ni++){var n=ns[ni],a=String((n.getAttribute&&n.getAttribute('aria-label'))||n.textContent||'').trim();if(a){profileAria.push(a);if(/非公開|Protected|private account|鍵/i.test(a))domProtected=true;}}}}catch(_){}return {ready:document.readyState,articleCount:document.querySelectorAll('article[data-testid=\\\"tweet\\\"]').length,tweetEntityCount:tweetEntityCount,userId:String(uid||''),posts:posts,joinedText:joinedText,domProtected:domProtected,profileAria:profileAria};})()",uidLiteral,screenLiteral];

    __weak typeof(self) weakSelf=self;
    __weak NativeProfileViewController *weakProfile=profile;
    __block NSInteger attempt=0;
    __block void (^poll)(void)=nil;
    poll=^{
        typeof(self) self=weakSelf;
        NativeProfileViewController *strongProfile=weakProfile;
        if(!self||!strongProfile){ poll=nil; return; }
        attempt++;
        [loader evaluateJavaScript:extract completionHandler:^(id result,NSError *error){
            typeof(self) self=weakSelf;
            NativeProfileViewController *strongProfile=weakProfile;
            if(!self||!strongProfile){ poll=nil; return; }
            NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?(NSDictionary *)result:nil;
            NSArray *posts=[dict[@"posts"] isKindOfClass:NSArray.class]?dict[@"posts"]:@[];
            NSNumber *tweetEntities=[dict[@"tweetEntityCount"] isKindOfClass:NSNumber.class]?dict[@"tweetEntityCount"]:@0;
            NSNumber *articles=[dict[@"articleCount"] isKindOfClass:NSNumber.class]?dict[@"articleCount"]:@0;
            BOOL finished=(posts.count>0||attempt>=18);
            if(finished){
                NSMutableDictionary *merged=[strongProfile.profileData mutableCopy]?:[base mutableCopy];
                merged[@"posts"]=posts;
                merged[@"postsLoading"]=@NO;
                NSString *joinedText=[dict[@"joinedText"] isKindOfClass:NSString.class]?dict[@"joinedText"]:@"";
                if(joinedText.length)merged[@"joinedText"]=joinedText;
                BOOL domProtected=[dict[@"domProtected"] respondsToSelector:@selector(boolValue)]?[dict[@"domProtected"] boolValue]:NO;
                if(domProtected)merged[@"protected"]=@YES;
                NSArray *profileAria=[dict[@"profileAria"] isKindOfClass:NSArray.class]?dict[@"profileAria"]:@[];
                merged[@"postProbe"]=@{@"mode":@"official-profile-route",@"attempts":@(attempt),@"tweetEntityCount":tweetEntities,@"matchedPosts":@(posts.count),@"articleCount":articles,@"joinedText":joinedText?:@"",@"domProtected":@(domProtected),@"profileAria":profileAria};
                [[DiagnosticsStore shared] addEvent:@"Native profile official post load" detail:[NSString stringWithFormat:@"attempts=%ld tweetEntities=%@ matchedPosts=%lu articles=%@",(long)attempt,tweetEntities,(unsigned long)posts.count,articles] url:loader.URL];
                dispatch_async(dispatch_get_main_queue(),^{ [strongProfile applyProfileData:merged]; });
                [self sx_finishProfileLoader:loader];
                poll=nil;
                return;
            }
            if(error&&attempt==1)[[DiagnosticsStore shared] addError:@"Native profile official loader initial probe failed" error:error url:loader.URL];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),poll);
        }];
    };

    [[DiagnosticsStore shared] addEvent:@"Native profile official post load started" detail:[NSString stringWithFormat:@"screen=@%@",screenName] url:url];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),poll);
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

    NSString *script=[NSString stringWithFormat:@"(function(){var uid=%@,screen=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var c=f.dependencies&&f.dependencies.firstContext;for(var i=0;c&&i<12;i++,c=c.next){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}}}return null;}function val(o,k){try{var v=o&&o[k];return(typeof v==='string'||typeof v==='number')?v:'';}catch(e){return '';}}var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=\\\"primaryColumn\\\"]'))||storeFromNode(document.body);if(!store)return {};var state;try{state=store.getState();}catch(e){return {};}var map=state&&state.entities&&state.entities.users&&state.entities.users.entities;if(!map||typeof map!=='object')return {};var entity=(uid&&map[uid])?map[uid]:null;if(!entity&&screen){var keys=Object.keys(map);for(var i=0;i<keys.length;i++){var e=map[keys[i]];var legacy=e&&e.legacy;if(val(e,'screen_name')===screen||val(legacy,'screen_name')===screen){entity=e;break;}}}if(!entity)return {};for(var uw=0;uw<5&&entity&&typeof entity==='object'&&!(entity.legacy||entity.core||entity.privacy);uw++){if(entity.result&&typeof entity.result==='object'){entity=entity.result;continue;}if(entity.user&&typeof entity.user==='object'){entity=entity.user;continue;}if(entity.user_results&&entity.user_results.result&&typeof entity.user_results.result==='object'){entity=entity.user_results.result;continue;}break;}var legacy=(entity.legacy&&typeof entity.legacy==='object')?entity.legacy:entity;if(!uid)uid=String(val(entity,'rest_id')||val(legacy,'id_str')||val(legacy,'user_id_str')||'');var avatar=val(legacy,'profile_image_url_https')||val(entity,'profile_image_url_https');if(typeof avatar==='string')avatar=avatar.replace('_normal.','_400x400.');var core=entity&&entity.core&&typeof entity.core==='object'?entity.core:{};var privacy=entity&&entity.privacy&&typeof entity.privacy==='object'?entity.privacy:{};var verification=entity&&entity.verification&&typeof entity.verification==='object'?entity.verification:null;return {name:String(val(core,'name')||val(legacy,'name')||val(entity,'name')||''),handle:(val(core,'screen_name')||val(legacy,'screen_name')||val(entity,'screen_name'))?'@'+String(val(core,'screen_name')||val(legacy,'screen_name')||val(entity,'screen_name')):'',bio:String(val(legacy,'description')||val(entity,'description')||''),avatarURL:String(avatar||''),bannerURL:String(val(legacy,'profile_banner_url')||val(entity,'profile_banner_url')||''),following:String(val(legacy,'friends_count')||val(entity,'friends_count')||''),followers:String(val(legacy,'followers_count')||val(entity,'followers_count')||''),createdAt:String(val(core,'created_at')||val(legacy,'created_at')||val(entity,'created_at')||''),verified:!!(entity.is_blue_verified||entity.verified||legacy.verified||(verification&&(verification.verified||(typeof verification.verified_type==='string'&&verification.verified_type.length)))),protected:!!(privacy.protected||legacy.protected||entity.protected),userId:String(uid||'')};})()",uidLiteral,screenLiteral];

    __weak typeof(self) weakSelf=self;
    [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf; if(!self)return;
        NSMutableDictionary *merged=[base mutableCopy];
        NSString *resolvedUserId=userId;
        NSString *resolvedScreen=screenName;
        if(!error&&[result isKindOfClass:NSDictionary.class]){
            NSDictionary *dict=(NSDictionary *)result;
            [dict enumerateKeysAndObjectsUsingBlock:^(id key,id obj,BOOL *stop){ if(([obj isKindOfClass:NSString.class]&&[(NSString *)obj length]>0)||[obj isKindOfClass:NSNumber.class])merged[key]=obj; }];
            NSString *rid=[dict[@"userId"] isKindOfClass:NSString.class]?dict[@"userId"]:@"";
            if(rid.length)resolvedUserId=rid;
            NSString *rh=[dict[@"handle"] isKindOfClass:NSString.class]?dict[@"handle"]:@"";
            if([rh hasPrefix:@"@"])rh=[rh substringFromIndex:1];
            if(rh.length)resolvedScreen=rh;
        } else if(error) {
            [[DiagnosticsStore shared] addError:@"Native profile extraction failed" error:error url:webView.URL];
        }
        merged[@"posts"]=@[];
        merged[@"postsLoading"]=@YES;
        NativeProfileViewController *profile=[self sx_presentNativeProfile:merged];
        [self sx_startOfficialProfilePostLoadForScreenName:resolvedScreen userId:resolvedUserId base:merged profile:profile sourceWebView:webView];
    }];
}

@end
