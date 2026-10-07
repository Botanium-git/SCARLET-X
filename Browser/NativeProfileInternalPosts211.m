#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileInternalPosts211)
@end

@implementation BrowserViewController (NativeProfileInternalPosts211)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL originalSEL = @selector(sx_startOfficialProfilePostLoadForScreenName:userId:base:profile:sourceWebView:);
        SEL replacementSEL = @selector(sx_211_startOfficialProfilePostLoadForScreenName:userId:base:profile:sourceWebView:);
        Method original = class_getInstanceMethod(self, originalSEL);
        Method replacement = class_getInstanceMethod(self, replacementSEL);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (NSString *)sx_211_jsonLiteral:(NSString *)value {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *array = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[\"\"]";
    if (array.length >= 2) return [array substringWithRange:NSMakeRange(1, array.length - 2)];
    return @"\"\"";
}

- (NSString *)sx_211_internalPostsScriptForUserId:(NSString *)userId {
    NSString *uid = [self sx_211_jsonLiteral:userId];
    return [NSString stringWithFormat:@"(function(){"
        "var uid=%@;"
        "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
        "function normalize(result){"
          "var out=[],seen={},profileMeta={};"
          "function takeProfile(v){try{if(!v||typeof v!=='object')return;var lg=v.legacy&&typeof v.legacy==='object'?v.legacy:{},co=v.core&&typeof v.core==='object'?v.core:{},pr=v.privacy&&typeof v.privacy==='object'?v.privacy:{},rid=String(val(v,'rest_id')||val(lg,'id_str')||val(v,'id_str')||'');if(rid!==String(uid))return;var ca=String(val(co,'created_at')||val(lg,'created_at')||val(v,'created_at')||'');if(ca)profileMeta.createdAt=ca;if(pr.protected!==undefined||lg.protected!==undefined||v.protected!==undefined)profileMeta.protected=!!(pr.protected||lg.protected||v.protected);if(v.is_blue_verified!==undefined||v.verified!==undefined)profileMeta.verified=!!(v.is_blue_verified||v.verified); }catch(_){}}"
          "function scanProfile(v,d){if(!v||d>9)return;if(Array.isArray(v)){for(var si=0;si<v.length;si++)scanProfile(v[si],d+1);return;}if(typeof v!=='object')return;takeProfile(v);var sk=[];try{sk=Object.keys(v);}catch(_){return;}for(var sj=0;sj<sk.length;sj++){var kk=sk[sj];if(kk==='feedbackInfo'||kk==='clientEventInfo')continue;scanProfile(v[kk],d+1);}}"
          "scanProfile(result,0);"
          "var instructions=result&&Array.isArray(result.instructions)?result.instructions:[];"
          "for(var ii=0;ii<instructions.length;ii++){"
            "var entries=Array.isArray(instructions[ii]&&instructions[ii].entries)?instructions[ii].entries:[];"
            "for(var ei=0;ei<entries.length;ei++){"
              "var content=entries[ei]&&entries[ei].content;"
              "var item=content&&content.itemContent;"
              "var tweet=item&&item.tweet_results&&item.tweet_results.result;"
              "if(!tweet||tweet.__typename!=='Tweet')continue;"
              "var legacy=tweet.legacy&&typeof tweet.legacy==='object'?tweet.legacy:null;"
              "if(!legacy)continue;"
              "var id=String(val(tweet,'rest_id')||val(legacy,'id_str')||'');"
              "if(!id||seen[id])continue;"
              "var owner=String(val(legacy,'user_id_str')||'');"
              "if(uid&&owner&&owner!==String(uid))continue;"
              "if(!profileMeta.createdAt){try{var ur=tweet.core&&tweet.core.user_results&&tweet.core.user_results.result;if(ur&&typeof ur==='object'){var uc=ur.core&&typeof ur.core==='object'?ur.core:{},up=ur.privacy&&typeof ur.privacy==='object'?ur.privacy:{},ul=ur.legacy&&typeof ur.legacy==='object'?ur.legacy:{};profileMeta={createdAt:String(val(uc,'created_at')||val(ul,'created_at')||val(ur,'created_at')||''),protected:!!(up.protected||ul.protected||ur.protected),verified:!!(ur.is_blue_verified||ur.verified||(ur.verification&&ur.verification.verified))};}}catch(_){}"
              "if(legacy.retweeted_status_id_str||tweet.retweeted_status_result||legacy.retweeted_status_result)continue;"
              "var text=String(val(legacy,'full_text')||'');"
              "var range=legacy.display_text_range;"
              "if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);"
              "var mediaURL='';"
              "var media=legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]);"
              "for(var mi=0;mi<media.length;mi++){var m=media[mi];if(m&&m.type==='photo'){mediaURL=String(val(m,'media_url_https')||val(m,'media_url')||'');if(mediaURL)break;}}"
              "seen[id]=true;"
              "out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),mediaURL:mediaURL,replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0)});"
            "}"
          "}"
          "return {posts:out,profileMeta:profileMeta};"
        "}"
        "try{"
          "var slot=window.__scarletXProfilePosts211;"
          "if(slot&&slot.userId===String(uid))return slot;"
          "var api=window.__scarletXAPI;"
          "if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};"
          "var q=window.webpackChunk_twitter_responsive_web,req=null;"
          "if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};"
          "var marker=950000000+Math.floor(Math.random()*40000000);q.push([[marker],{},function(r){req=r;}]);"
          "if(!req)return {state:'waiting-require',userId:String(uid)};"
          "var epm=req(923288),factory=epm&&epm.Ay;"
          "if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};"
          "var endpoint=api.withEndpoint(factory);"
          "if(!endpoint||typeof endpoint.fetchUserOriginals!=='function')return {state:'error',stage:'endpoint',userId:String(uid)};"
          "window.__scarletXProfilePosts211={state:'loading',userId:String(uid)};"
          "Promise.resolve(endpoint.fetchUserOriginals({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false})).then(function(result){"
            "try{var normalized=normalize(result);window.__scarletXProfilePosts211={state:'success',userId:String(uid),posts:normalized.posts||[],profileMeta:normalized.profileMeta||{}};}catch(e){window.__scarletXProfilePosts211={state:'error',stage:'normalize',userId:String(uid),message:String(e&&e.stack||e)};}"
          "}).catch(function(e){window.__scarletXProfilePosts211={state:'error',stage:'request',userId:String(uid),message:String(e&&e.stack||e)};});"
          "return window.__scarletXProfilePosts211;"
        "}catch(e){return {state:'error',stage:'exception',userId:String(uid),message:String(e&&e.stack||e)};}"
      "})()", uid];
}

- (NSString *)sx_229_internalRepliesScriptForUserId:(NSString *)userId {
    NSString *uid=[self sx_211_jsonLiteral:userId];
    return [NSString stringWithFormat:@"(function(){"
      "var uid=%@;"
      "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
      "function normalizeMedia(legacy){var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]),out=[];for(var i=0;i<raw.length;i++){var m=raw[i];if(!m)continue;var type=String(val(m,'type')||''),preview=String(val(m,'media_url_https')||val(m,'media_url')||'');if(!preview)continue;var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0,videoURL='',vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null,vars=vi&&Array.isArray(vi.variants)?vi.variants:[],best=-1;for(var j=0;j<vars.length;j++){var vr=vars[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;var bit=Number(val(vr,'bitrate')||0),u=String(val(vr,'url')||'');if(u&&bit>=best){best=bit;videoURL=u;}}out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});}return out;}"
      "function normalize(result){var out=[],seen={};function take(tweet){if(!tweet||tweet.__typename!=='Tweet')return;var legacy=tweet.legacy&&typeof tweet.legacy==='object'?tweet.legacy:null;if(!legacy)return;var id=String(val(tweet,'rest_id')||val(legacy,'id_str')||'');if(!id||seen[id])return;var owner=String(val(legacy,'user_id_str')||'');if(uid&&owner&&owner!==String(uid))return;if(legacy.retweeted_status_id_str||tweet.retweeted_status_result||legacy.retweeted_status_result)return;if(!legacy.in_reply_to_status_id_str&&!legacy.in_reply_to_user_id_str)return;var text=String(val(legacy,'full_text')||''),range=legacy.display_text_range;if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);var media=normalizeMedia(legacy);seen[id]=true;out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):'',replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0)});}function walk(v,d){if(!v||d>7)return;if(v.tweet_results&&v.tweet_results.result){take(v.tweet_results.result);return;}if(Array.isArray(v)){for(var i=0;i<v.length;i++)walk(v[i],d+1);return;}if(typeof v!=='object')return;var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var j=0;j<ks.length;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;walk(v[k],d+1);}}walk(result,0);return out;}"
      "try{var slot=window.__scarletXProfileReplies229;if(slot&&slot.userId===String(uid))return slot;var api=window.__scarletXAPI;if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};var q=window.webpackChunk_twitter_responsive_web,req=null;if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};var marker=970000000+Math.floor(Math.random()*20000000);q.push([[marker],{},function(r){req=r;}]);if(!req)return {state:'waiting-require',userId:String(uid)};var epm=req(923288),factory=epm&&epm.Ay;if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};var endpoint=api.withEndpoint(factory);if(!endpoint||typeof endpoint.fetchUserReplies!=='function')return {state:'error',stage:'fetchUserReplies-unavailable',userId:String(uid)};window.__scarletXProfileReplies229={state:'loading',userId:String(uid)};Promise.resolve(endpoint.fetchUserReplies({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false})).then(function(result){try{window.__scarletXProfileReplies229={state:'success',userId:String(uid),replies:normalize(result)};}catch(e){window.__scarletXProfileReplies229={state:'error',stage:'normalize',userId:String(uid),message:String(e&&e.stack||e)};}}).catch(function(e){window.__scarletXProfileReplies229={state:'error',stage:'request',userId:String(uid),message:String(e&&e.stack||e)};});return window.__scarletXProfileReplies229;}catch(e){return {state:'error',stage:'exception',userId:String(uid),message:String(e&&e.stack||e)};}"
    "})()",uid];
}

- (void)sx_229_startReplyLoadForUserId:(NSString *)userId profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    if(userId.length==0||![sourceWebView isKindOfClass:WKWebView.class]||!profile)return;
    NSMutableDictionary *replyInitial=[profile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
    replyInitial[@"repliesLoading"]=@YES;
    dispatch_async(dispatch_get_main_queue(),^{ [profile applyProfileData:replyInitial]; });
    NSString *script=[self sx_229_internalRepliesScriptForUserId:userId];
    __weak NativeProfileViewController *weakProfile=profile;
    __weak WKWebView *weakWebView=sourceWebView;
    __block NSInteger attempt=0;
    __block void (^poll)(void)=nil;
    poll=^{
        NativeProfileViewController *strongProfile=weakProfile;
        WKWebView *webView=weakWebView;
        if(!strongProfile||!webView){poll=nil;return;}
        attempt++;
        [webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){
            NativeProfileViewController *strongProfile=weakProfile;
            WKWebView *webView=weakWebView;
            if(!strongProfile||!webView){poll=nil;return;}
            NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?(NSDictionary *)result:nil;
            NSString *state=[dict[@"state"] isKindOfClass:NSString.class]?dict[@"state"]:@"";
            if(!error&&[state isEqualToString:@"success"]){
                NSArray *replies=[dict[@"replies"] isKindOfClass:NSArray.class]?dict[@"replies"]:@[];
                NSMutableDictionary *merged=[strongProfile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
                merged[@"replies"]=replies;
                merged[@"repliesLoading"]=@NO;
                merged[@"replyProbe"]=@{@"mode":@"internal-api-229",@"attempts":@(attempt),@"matchedReplies":@(replies.count)};
                [[DiagnosticsStore shared] addEvent:@"Native profile internal API reply load" detail:[NSString stringWithFormat:@"attempts=%ld matchedReplies=%lu",(long)attempt,(unsigned long)replies.count] url:webView.URL];
                dispatch_async(dispatch_get_main_queue(),^{[strongProfile applyProfileData:merged];});
                poll=nil;
                return;
            }
            BOOL explicitError=[state isEqualToString:@"error"];
            if(explicitError||attempt>=24){
                NSMutableDictionary *merged=[strongProfile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
                merged[@"replies"]=@[];
                merged[@"repliesLoading"]=@NO;
                NSString *stage=[dict[@"stage"] isKindOfClass:NSString.class]?dict[@"stage"]:(error?@"evaluate":@"timeout");
                merged[@"replyProbe"]=@{@"mode":@"internal-api-229",@"attempts":@(attempt),@"stage":stage?:@""};
                [[DiagnosticsStore shared] addEvent:@"Native profile internal API reply load failed" detail:[NSString stringWithFormat:@"attempts=%ld stage=%@",(long)attempt,stage] url:webView.URL];
                dispatch_async(dispatch_get_main_queue(),^{[strongProfile applyProfileData:merged];});
                poll=nil;
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),poll);
        }];
    };
    [[DiagnosticsStore shared] addEvent:@"Native profile internal API reply load started" detail:[NSString stringWithFormat:@"userId=%@",userId] url:sourceWebView.URL];
    poll();
}

- (NSString *)sx_211_profileMetaFromReduxScriptForUserId:(NSString *)userId screenName:(NSString *)screenName {
    NSString *uid=[self sx_211_jsonLiteral:userId?:@""], *sn=[self sx_211_jsonLiteral:screenName?:@""];
    return [NSString stringWithFormat:@"(function(){try{var uid=%@,sn=%@,p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');function fiberOf(n){if(!n)return null;var ks=Object.keys(n);for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var dep=f.dependencies&&f.dependencies.firstContext;for(var j=0;dep&&j<10;j++,dep=dep.next){var vals=[dep.memoizedValue,dep.context&&dep.context._currentValue2,dep.context&&dep.context._currentValue];for(var k=0;k<vals.length;k++){var s=asStore(vals[k]);if(s)return s;}}var direct=asStore(f.memoizedProps);if(direct)return direct;}return null;}var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store)return {found:false,stage:'no-store'};var st=store.getState(),eu=st&&st.entities&&st.entities.users,em=eu&&eu.entities;if(!em||typeof em!=='object')return {found:false,stage:'no-entities'};var hit=(uid&&em[uid]&&typeof em[uid]==='object')?em[uid]:null;if(!hit&&sn){var keys=Object.keys(em);for(var i=0;i<keys.length;i++){var v=em[keys[i]],lg=v&&v.legacy;if(v&&((v.screen_name===sn)||(lg&&lg.screen_name===sn))){hit=v;break;}}}for(var w=0;w<5&&hit&&typeof hit==='object'&&!(hit.legacy||hit.core||hit.privacy);w++){if(hit.result&&typeof hit.result==='object')hit=hit.result;else if(hit.user&&typeof hit.user==='object')hit=hit.user;else if(hit.user_results&&hit.user_results.result)hit=hit.user_results.result;else break;}if(!hit)return {found:false,stage:'no-user'};var lg=hit.legacy||{},co=hit.core||{},pr=hit.privacy||{};var hasProtected=(Object.prototype.hasOwnProperty.call(pr,'protected')||Object.prototype.hasOwnProperty.call(lg,'protected')||Object.prototype.hasOwnProperty.call(hit,'protected'));return {found:true,createdAt:String(co.created_at||lg.created_at||hit.created_at||''),hasProtected:hasProtected,protected:!!(pr.protected||lg.protected||hit.protected),verified:!!(hit.is_blue_verified||hit.verified||lg.verified)};}catch(e){return {found:false,stage:'exception',message:String(e)}}})()",uid,sn];
}

- (void)sx_211_startOfficialProfilePostLoadForScreenName:(NSString *)screenName
                                                  userId:(NSString *)userId
                                                    base:(NSDictionary *)base
                                                 profile:(NativeProfileViewController *)profile
                                           sourceWebView:(WKWebView *)sourceWebView {
    if (userId.length == 0 || ![sourceWebView isKindOfClass:WKWebView.class] || !profile) {
        [self sx_211_startOfficialProfilePostLoadForScreenName:screenName userId:userId base:base profile:profile sourceWebView:sourceWebView];
        return;
    }

    NSMutableDictionary *postInitial=[profile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
    if(postInitial.count==0&&base) [postInitial addEntriesFromDictionary:base];
    postInitial[@"postsLoading"]=@YES;
    dispatch_async(dispatch_get_main_queue(),^{ [profile applyProfileData:postInitial]; });

    [self sx_229_startReplyLoadForUserId:userId profile:profile sourceWebView:sourceWebView];

    NSString *script = [self sx_211_internalPostsScriptForUserId:userId];
    __weak typeof(self) weakSelf = self;
    __weak NativeProfileViewController *weakProfile = profile;
    __weak WKWebView *weakWebView = sourceWebView;
    __block NSInteger attempt = 0;
    __block void (^poll)(void) = nil;

    poll = ^{
        typeof(self) self = weakSelf;
        NativeProfileViewController *strongProfile = weakProfile;
        WKWebView *webView = weakWebView;
        if (!self || !strongProfile || !webView) { poll = nil; return; }
        attempt++;

        [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            typeof(self) self = weakSelf;
            NativeProfileViewController *strongProfile = weakProfile;
            WKWebView *webView = weakWebView;
            if (!self || !strongProfile || !webView) { poll = nil; return; }

            NSDictionary *dict = [result isKindOfClass:NSDictionary.class] ? (NSDictionary *)result : nil;
            NSString *state = [dict[@"state"] isKindOfClass:NSString.class] ? dict[@"state"] : @"";

            if (!error && [state isEqualToString:@"success"]) {
                NSArray *posts = [dict[@"posts"] isKindOfClass:NSArray.class] ? dict[@"posts"] : @[];
                NSDictionary *profileMeta=[dict[@"profileMeta"] isKindOfClass:NSDictionary.class]?dict[@"profileMeta"]:@{};
                NSMutableDictionary *merged = [strongProfile.profileData mutableCopy] ?: [NSMutableDictionary dictionary];
                if(merged.count==0&&base) [merged addEntriesFromDictionary:base];
                merged[@"posts"] = posts;
                merged[@"postsLoading"] = @NO;
                NSString *profileCreatedAt=[profileMeta[@"createdAt"] isKindOfClass:NSString.class]?profileMeta[@"createdAt"]:@"";
                if(profileCreatedAt.length)merged[@"createdAt"]=profileCreatedAt;
                if([profileMeta[@"protected"] respondsToSelector:@selector(boolValue)])merged[@"protected"]=@([profileMeta[@"protected"] boolValue]);
                if([profileMeta[@"verified"] respondsToSelector:@selector(boolValue)])merged[@"verified"]=@([profileMeta[@"verified"] boolValue]);
                merged[@"postProbe"] = @{ @"mode": @"internal-api-211", @"attempts": @(attempt), @"matchedPosts": @(posts.count), @"profileCreatedAt": profileCreatedAt ?: @"", @"profileProtected": @([profileMeta[@"protected"] boolValue]) };
                [[DiagnosticsStore shared] addEvent:@"Native profile internal API post load"
                                               detail:[NSString stringWithFormat:@"attempts=%ld matchedPosts=%lu", (long)attempt, (unsigned long)posts.count]
                                                  url:webView.URL];
                dispatch_async(dispatch_get_main_queue(), ^{ [strongProfile applyProfileData:merged]; });
                poll = nil;
                if(profileCreatedAt.length==0 || ![profileMeta[@"protected"] respondsToSelector:@selector(boolValue)]){
                    NSString *metaScript=[self sx_211_profileMetaFromReduxScriptForUserId:userId screenName:screenName];
                    [webView evaluateJavaScript:metaScript completionHandler:^(id metaResult,NSError *metaError){
                        NSDictionary *md=[metaResult isKindOfClass:NSDictionary.class]?(NSDictionary *)metaResult:nil;
                        if(!metaError&&[md[@"found"] boolValue]){
                            NSMutableDictionary *finalData=[strongProfile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
                            NSString *ca=[md[@"createdAt"] isKindOfClass:NSString.class]?md[@"createdAt"]:@"";
                            if(ca.length)finalData[@"createdAt"]=ca;
                            if([md[@"hasProtected"] boolValue])finalData[@"protected"]=@([md[@"protected"] boolValue]);
                            if([md[@"verified"] respondsToSelector:@selector(boolValue)])finalData[@"verified"]=@([md[@"verified"] boolValue]);
                            finalData[@"profileMetaProbe"]=md;
                            dispatch_async(dispatch_get_main_queue(),^{[strongProfile applyProfileData:finalData];});
                            [[DiagnosticsStore shared] addEvent:@"Native profile Redux metadata applied" detail:[md description] url:webView.URL];
                        } else {
                            [[DiagnosticsStore shared] addEvent:@"Native profile Redux metadata missing" detail:[md description]?:@"" url:webView.URL];
                        }
                    }];
                }
                return;
            }

            BOOL explicitError = [state isEqualToString:@"error"];
            if (explicitError || attempt >= 24) {
                NSString *stage = [dict[@"stage"] isKindOfClass:NSString.class] ? dict[@"stage"] : (error ? @"evaluate" : @"timeout");
                [[DiagnosticsStore shared] addEvent:@"Native profile internal API fallback"
                                               detail:[NSString stringWithFormat:@"attempts=%ld stage=%@", (long)attempt, stage]
                                                  url:webView.URL];
                poll = nil;
                [self sx_211_startOfficialProfilePostLoadForScreenName:screenName userId:userId base:base profile:strongProfile sourceWebView:webView];
                return;
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), poll);
        }];
    };

    [[DiagnosticsStore shared] addEvent:@"Native profile internal API post load started"
                                   detail:[NSString stringWithFormat:@"userId=%@ screen=@%@", userId, screenName ?: @""]
                                      url:sourceWebView.URL];
    poll();
}

@end
