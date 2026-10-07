#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileReposts236Private)
- (NSString *)sx_211_jsonLiteral:(NSString *)value;
- (void)sx_229_startReplyLoadForUserId:(NSString *)userId profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView;
- (void)sx287_startMediaLoadForUserId:(NSString *)userId profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView;
@end

@implementation BrowserViewController (NativeProfileReposts236)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(sx_229_startReplyLoadForUserId:profile:sourceWebView:));
        Method replacement=class_getInstanceMethod(self,@selector(sx236_startReplyLoadForUserId:profile:sourceWebView:));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (NSString *)sx236_repostsScriptForUserId:(NSString *)userId {
    NSString *uid=[self sx_211_jsonLiteral:userId];
    return [NSString stringWithFormat:@"(function(){"
      "var uid=%@,KEY='__scarletXProfileReposts236';"
      "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
      "function mediaFor(legacy){var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]),out=[];for(var i=0;i<raw.length;i++){var m=raw[i];if(!m)continue;var type=String(val(m,'type')||''),preview=String(val(m,'media_url_https')||val(m,'media_url')||'');if(!preview)continue;var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0,videoURL='',vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null,vars=vi&&Array.isArray(vi.variants)?vi.variants:[],best=-1;for(var j=0;j<vars.length;j++){var vr=vars[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;var bit=Number(val(vr,'bitrate')||0),u=String(val(vr,'url')||'');if(u&&bit>=best){best=bit;videoURL=u;}}out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});}return out;}"
      "function userFor(tweet){var u=tweet&&tweet.core&&tweet.core.user_results&&tweet.core.user_results.result;for(var i=0;i<5&&u&&typeof u==='object'&&!(u.legacy&&typeof u.legacy==='object')&&!(u.core&&typeof u.core==='object');i++){if(u.user&&typeof u.user==='object'){u=u.user;continue;}if(u.result&&typeof u.result==='object'){u=u.result;continue;}if(u.user_results&&u.user_results.result&&typeof u.user_results.result==='object'){u=u.user_results.result;continue;}break;}if(!u||typeof u!=='object')return {};var l=u.legacy&&typeof u.legacy==='object'?u.legacy:{},c=u.core&&typeof u.core==='object'?u.core:{},a=u.avatar&&typeof u.avatar==='object'?u.avatar:{};var privacy=u.privacy&&typeof u.privacy==='object'?u.privacy:null;var verification=u.verification&&typeof u.verification==='object'?u.verification:null;return {authorName:String(val(c,'name')||val(l,'name')||''),authorHandle:String(val(c,'screen_name')||val(l,'screen_name')||''),authorAvatarURL:String(val(a,'image_url')||val(l,'profile_image_url_https')||val(l,'profile_image_url')||'').replace(/_normal(?=\\.[A-Za-z0-9]+(?:\\?|$))/, '_400x400'),authorVerified:!!(u.is_blue_verified||u.verified||l.verified||(verification&&(verification.verified||(typeof verification.verified_type==='string'&&verification.verified_type.length)))),authorProtected:!!((privacy&&privacy.protected)||l.protected||u.protected)};}"
      "function tweetResult(v){for(var i=0;i<5&&v&&typeof v==='object';i++){if(v.__typename==='Tweet')return v;if(v.tweet&&typeof v.tweet==='object'){v=v.tweet;continue;}if(v.result&&typeof v.result==='object'){v=v.result;continue;}break;}return null;}function unwrap(tweet){try{var base=tweetResult(tweet)||tweet,rr=base&&base.retweeted_status_result&&base.retweeted_status_result.result,res=tweetResult(rr);if(res)return res;var l=base&&base.legacy;rr=l&&l.retweeted_status_result&&l.retweeted_status_result.result;res=tweetResult(rr);if(res)return res;return base;}catch(_){return tweetResult(tweet)||tweet;}}"
      "function probe(result){var raw=null;function keys(v){try{return v&&typeof v==='object'?Object.keys(v).slice(0,24):[];}catch(_){return [];}}function find(v,d){if(raw||!v||d>12)return;if(v.tweet_results&&v.tweet_results.result){raw=v.tweet_results.result;return;}if(Array.isArray(v)){for(var i=0;i<v.length&&!raw;i++)find(v[i],d+1);return;}if(typeof v!=='object')return;var ks=keys(v);for(var j=0;j<ks.length&&!raw;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;find(v[k],d+1);}}find(result,0);var base=tweetResult(raw)||raw,rr1=base&&base.retweeted_status_result&&base.retweeted_status_result.result,rr2=base&&base.legacy&&base.legacy.retweeted_status_result&&base.legacy.retweeted_status_result.result,un=unwrap(raw),ur=un&&un.core&&un.core.user_results&&un.core.user_results.result;return {rawType:String(val(raw,'__typename')||''),rawKeys:keys(raw),baseType:String(val(base,'__typename')||''),baseKeys:keys(base),directRetweetKeys:keys(rr1),legacyRetweetKeys:keys(rr2),unwrappedType:String(val(un,'__typename')||''),unwrappedKeys:keys(un),coreKeys:keys(un&&un.core),userResultType:String(val(ur,'__typename')||''),userResultKeys:keys(ur),userLegacyKeys:keys(ur&&ur.legacy),userCoreKeys:keys(ur&&ur.core)};}"
      "function normalize(result){var out=[],seen={};function take(rawTweet){if(!rawTweet||rawTweet.__typename!=='Tweet')return;var tweet=unwrap(rawTweet);if(!tweet||tweet.__typename!=='Tweet')return;var legacy=tweet.legacy&&typeof tweet.legacy==='object'?tweet.legacy:null;if(!legacy)return;var id=String(val(tweet,'rest_id')||val(legacy,'id_str')||'');if(!id||seen[id])return;var text=String(val(legacy,'full_text')||''),range=legacy.display_text_range;if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);var media=mediaFor(legacy),author=userFor(tweet);seen[id]=true;out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):'',replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0),authorName:author.authorName||'',authorHandle:author.authorHandle||'',authorAvatarURL:author.authorAvatarURL||'',authorVerified:!!author.authorVerified,authorProtected:!!author.authorProtected,isRepost:true});}function walk(v,d){if(!v||d>10)return;if(v.tweet_results&&v.tweet_results.result){take(v.tweet_results.result);return;}if(Array.isArray(v)){for(var i=0;i<v.length;i++)walk(v[i],d+1);return;}if(typeof v!=='object')return;var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var j=0;j<ks.length;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;walk(v[k],d+1);}}walk(result,0);return out;}"
      "function timed(p,ms){return Promise.race([Promise.resolve(p),new Promise(function(_,reject){setTimeout(function(){reject(new Error('fetchUserReposts-timeout'));},ms);})]);}"
      "try{var slot=window[KEY];if(slot&&slot.userId===String(uid)){if(slot.state==='success'||slot.state==='error')return slot;if(slot.state==='loading'&&Date.now()-Number(slot.startedAt||0)<7000)return slot;delete window[KEY];}var api=window.__scarletXAPI;if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};var q=window.webpackChunk_twitter_responsive_web,req=null;if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};var marker=982000000+Math.floor(Math.random()*8000000);q.push([[marker],{},function(r){req=r;}]);if(!req)return {state:'waiting-require',userId:String(uid)};var epm=req(923288),factory=epm&&epm.Ay;if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};var endpoint=api.withEndpoint(factory);if(!endpoint||typeof endpoint.fetchUserReposts!=='function')return {state:'error',stage:'fetchUserReposts-unavailable',userId:String(uid)};window[KEY]={state:'loading',userId:String(uid),startedAt:Date.now()};timed(endpoint.fetchUserReposts({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false}),5000).then(function(result){try{window[KEY]={state:'success',userId:String(uid),reposts:normalize(result),probe:probe(result),finishedAt:Date.now()};}catch(e){window[KEY]={state:'error',stage:'normalize',userId:String(uid),message:String(e&&e.stack||e),finishedAt:Date.now()};}}).catch(function(e){window[KEY]={state:'error',stage:'request',userId:String(uid),message:String(e&&e.stack||e),finishedAt:Date.now()};});return window[KEY];}catch(e){return {state:'error',stage:'exception',userId:String(uid),message:String(e&&e.stack||e)};}"
    "})()",uid];
}

- (void)sx236_startRepostLoadForUserId:(NSString *)userId profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    if(userId.length==0||![sourceWebView isKindOfClass:WKWebView.class]||!profile)return;
    NSMutableDictionary *initial=[profile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
    initial[@"repostsLoading"]=@YES;
    dispatch_async(dispatch_get_main_queue(),^{ [profile applyProfileData:initial]; });

    NSString *script=[self sx236_repostsScriptForUserId:userId];
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
                NSArray *items=[dict[@"reposts"] isKindOfClass:NSArray.class]?dict[@"reposts"]:@[];
                NSMutableDictionary *merged=[strongProfile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
                merged[@"reposts"]=items;
                merged[@"repostsLoading"]=@NO;
                merged[@"repostProbe"]=@{@"mode":@"fetchUserReposts-236",@"attempts":@(attempt),@"matched":@(items.count)};
                [[DiagnosticsStore shared] addEvent:@"Native profile repost load" detail:[NSString stringWithFormat:@"attempts=%ld matched=%lu",(long)attempt,(unsigned long)items.count] url:webView.URL];
                NSDictionary *probe=[dict[@"probe"] isKindOfClass:NSDictionary.class]?dict[@"probe"]:nil;
                if(probe){ NSData *probeData=[NSJSONSerialization dataWithJSONObject:probe options:0 error:nil]; NSString *probeText=probeData?[[NSString alloc] initWithData:probeData encoding:NSUTF8StringEncoding]:[probe description]; [[DiagnosticsStore shared] addEvent:@"Native profile repost author probe" detail:probeText?:@"{}" url:webView.URL]; }
                dispatch_async(dispatch_get_main_queue(),^{ [strongProfile applyProfileData:merged]; });
                poll=nil;return;
            }
            BOOL explicitError=[state isEqualToString:@"error"];
            if(explicitError||attempt>=16){
                NSMutableDictionary *merged=[strongProfile.profileData mutableCopy]?:[NSMutableDictionary dictionary];
                merged[@"reposts"]=@[];
                merged[@"repostsLoading"]=@NO;
                NSString *stage=[dict[@"stage"] isKindOfClass:NSString.class]?dict[@"stage"]:(error?@"evaluate":@"timeout");
                merged[@"repostProbe"]=@{@"mode":@"fetchUserReposts-236",@"attempts":@(attempt),@"stage":stage?:@""};
                [[DiagnosticsStore shared] addEvent:@"Native profile repost load failed" detail:[NSString stringWithFormat:@"attempts=%ld stage=%@",(long)attempt,stage] url:webView.URL];
                dispatch_async(dispatch_get_main_queue(),^{ [strongProfile applyProfileData:merged]; });
                poll=nil;return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),poll);
        }];
    };
    poll();
}

- (void)sx236_startReplyLoadForUserId:(NSString *)userId profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    [self sx236_startReplyLoadForUserId:userId profile:profile sourceWebView:sourceWebView];
    [self sx236_startRepostLoadForUserId:userId profile:profile sourceWebView:sourceWebView];
    [self sx287_startMediaLoadForUserId:userId profile:profile sourceWebView:sourceWebView];
}

@end
