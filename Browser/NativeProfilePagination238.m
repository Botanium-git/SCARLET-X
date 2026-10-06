#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController (NativeProfilePagination238Private)
- (NSString *)sx_211_jsonLiteral:(NSString *)value;
@end

@implementation BrowserViewController (NativeProfilePagination238)

- (NSString *)sx238_pageScriptForTab:(NSInteger)tab userId:(NSString *)userId cursor:(NSString *)cursor {
    NSString *uid=[self sx_211_jsonLiteral:userId ?: @""];
    NSString *cur=[self sx_211_jsonLiteral:cursor ?: @""];
    return [NSString stringWithFormat:@"(function(){"
      "var uid=%@,requestedCursor=%@,mode=%ld,KEY='__scarletXProfilePage238_'+String(%ld);"
      "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
      "function mediaFor(legacy){var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]),out=[];for(var i=0;i<raw.length;i++){var m=raw[i];if(!m)continue;var type=String(val(m,'type')||''),preview=String(val(m,'media_url_https')||val(m,'media_url')||'');if(!preview)continue;var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0,videoURL='',vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null,vars=vi&&Array.isArray(vi.variants)?vi.variants:[],best=-1;for(var j=0;j<vars.length;j++){var vr=vars[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;var bit=Number(val(vr,'bitrate')||0),u=String(val(vr,'url')||'');if(u&&bit>=best){best=bit;videoURL=u;}}out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});}return out;}"
      "function userFor(tweet){var u=tweet&&tweet.core&&tweet.core.user_results&&tweet.core.user_results.result;for(var i=0;i<5&&u&&typeof u==='object'&&!(u.legacy&&typeof u.legacy==='object')&&!(u.core&&typeof u.core==='object');i++){if(u.user&&typeof u.user==='object'){u=u.user;continue;}if(u.result&&typeof u.result==='object'){u=u.result;continue;}if(u.user_results&&u.user_results.result&&typeof u.user_results.result==='object'){u=u.user_results.result;continue;}break;}if(!u||typeof u!=='object')return {};var l=u.legacy&&typeof u.legacy==='object'?u.legacy:{},c=u.core&&typeof u.core==='object'?u.core:{},a=u.avatar&&typeof u.avatar==='object'?u.avatar:{};return {authorName:String(val(c,'name')||val(l,'name')||''),authorHandle:String(val(c,'screen_name')||val(l,'screen_name')||''),authorAvatarURL:String(val(a,'image_url')||val(l,'profile_image_url_https')||val(l,'profile_image_url')||'')};}"
      "function tweetResult(v){for(var i=0;i<5&&v&&typeof v==='object';i++){if(v.__typename==='Tweet')return v;if(v.tweet&&typeof v.tweet==='object'){v=v.tweet;continue;}if(v.result&&typeof v.result==='object'){v=v.result;continue;}break;}return null;}function unwrap(tweet){try{var base=tweetResult(tweet)||tweet,rr=base&&base.retweeted_status_result&&base.retweeted_status_result.result,res=tweetResult(rr);if(res)return res;var l=base&&base.legacy;rr=l&&l.retweeted_status_result&&l.retweeted_status_result.result;res=tweetResult(rr);if(res)return res;return base;}catch(_){return tweetResult(tweet)||tweet;}}"
      "function normalize(result){var out=[],seen={};function take(rawTweet){if(!rawTweet||rawTweet.__typename!=='Tweet')return;var tweet=(mode===2)?unwrap(rawTweet):rawTweet;if(!tweet||tweet.__typename!=='Tweet')return;var legacy=tweet.legacy&&typeof tweet.legacy==='object'?tweet.legacy:null;if(!legacy)return;var id=String(val(tweet,'rest_id')||val(legacy,'id_str')||'');if(!id||seen[id])return;if(mode!==2){var owner=String(val(legacy,'user_id_str')||'');if(uid&&owner&&owner!==String(uid))return;if(legacy.retweeted_status_id_str||tweet.retweeted_status_result||legacy.retweeted_status_result)return;if(mode===1&&!legacy.in_reply_to_status_id_str&&!legacy.in_reply_to_user_id_str)return;}var text=String(val(legacy,'full_text')||''),range=legacy.display_text_range;if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);var media=mediaFor(legacy),author=(mode===2)?userFor(tweet):{};seen[id]=true;out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):'',replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0),authorName:author.authorName||'',authorHandle:author.authorHandle||'',authorAvatarURL:author.authorAvatarURL||'',isRepost:(mode===2)});}function walk(v,d){if(!v||d>10)return;if(v.tweet_results&&v.tweet_results.result){take(v.tweet_results.result);return;}if(Array.isArray(v)){for(var i=0;i<v.length;i++)walk(v[i],d+1);return;}if(typeof v!=='object')return;var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var j=0;j<ks.length;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;walk(v[k],d+1);}}walk(result,0);return out;}"
      "function bottomCursor(result){var found='';function walk(v,d){if(found||!v||d>12)return;if(Array.isArray(v)){for(var i=0;i<v.length&&!found;i++)walk(v[i],d+1);return;}if(typeof v!=='object')return;var type=String(val(v,'cursorType')||''),value=String(val(v,'value')||''),entryId=String(val(v,'entryId')||'');if(value&&(type==='Bottom'||entryId.indexOf('cursor-bottom')>=0)){found=value;return;}var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var j=0;j<ks.length&&!found;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;walk(v[k],d+1);}}walk(result,0);return found;}"
      "function timed(p,ms,label){return Promise.race([Promise.resolve(p),new Promise(function(_,reject){setTimeout(function(){reject(new Error(label));},ms);})]);}"
      "function makeRequest(endpoint,cursor){var args={userId:String(uid),count:20,cursor:cursor||void 0,isPaymentsEnrolled:false,sortByMostLiked:false};if(mode===0){if(typeof endpoint.fetchUserOriginals!=='function')throw new Error('fetchUserOriginals-unavailable');return timed(endpoint.fetchUserOriginals(args),6000,'posts-timeout');}if(mode===2){if(typeof endpoint.fetchUserReposts!=='function')throw new Error('fetchUserReposts-unavailable');return timed(endpoint.fetchUserReposts(args),6000,'reposts-timeout');}var fallback=function(){if(typeof endpoint.fetchUserTweetsAndReplies!=='function')throw new Error('replies-fallback-unavailable');return timed(endpoint.fetchUserTweetsAndReplies(args),6000,'replies-fallback-timeout');};if(typeof endpoint.fetchUserReplies!=='function')return fallback();return timed(endpoint.fetchUserReplies(args),3500,'replies-timeout').then(function(r){var list=normalize(r),c=bottomCursor(r);if(list.length||c)return r;return fallback();}).catch(function(){return fallback();});}"
      "function pack(result){return {items:normalize(result),nextCursor:bottomCursor(result)};}"
      "try{var slot=window[KEY];if(slot&&slot.userId===String(uid)&&slot.requestedCursor===String(requestedCursor)){if(slot.state==='success')return slot;if(slot.state==='loading'&&Date.now()-Number(slot.startedAt||0)<15000)return slot;delete window[KEY];}var api=window.__scarletXAPI;if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};var q=window.webpackChunk_twitter_responsive_web,req=null;if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};var marker=991000000+Math.floor(Math.random()*8000000);q.push([[marker],{},function(r){req=r;}]);if(!req)return {state:'waiting-require',userId:String(uid)};var epm=req(923288),factory=epm&&epm.Ay;if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};var endpoint=api.withEndpoint(factory);if(!endpoint)return {state:'error',stage:'endpoint',userId:String(uid)};window[KEY]={state:'loading',userId:String(uid),requestedCursor:String(requestedCursor),startedAt:Date.now()};var chain;if(requestedCursor){chain=makeRequest(endpoint,requestedCursor).then(pack);}else{chain=makeRequest(endpoint,void 0).then(function(first){var firstCursor=bottomCursor(first);if(!firstCursor)return {items:[],nextCursor:''};return makeRequest(endpoint,firstCursor).then(pack);});}Promise.resolve(chain).then(function(p){window[KEY]={state:'success',userId:String(uid),requestedCursor:String(requestedCursor),items:p.items||[],nextCursor:String(p.nextCursor||''),finishedAt:Date.now()};}).catch(function(e){window[KEY]={state:'error',userId:String(uid),requestedCursor:String(requestedCursor),stage:'request',message:String(e&&e.stack||e||''),finishedAt:Date.now()};});return window[KEY];}catch(e){return {state:'error',stage:'exception',message:String(e&&e.stack||e||''),userId:String(uid)};}"
    "})()",uid,cur,(long)tab,(long)tab];
}

- (void)sx238_loadMoreTab:(NSInteger)tab profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    if(tab<0||tab>2||!profile||![sourceWebView isKindOfClass:WKWebView.class])return;
    NSDictionary *data=[profile.profileData isKindOfClass:NSDictionary.class]?profile.profileData:@{};
    NSString *userId=[data[@"userId"] isKindOfClass:NSString.class]?data[@"userId"]:@"";
    if(userId.length==0){
        NSDictionary *probe=[data[@"followerProbe"] isKindOfClass:NSDictionary.class]?data[@"followerProbe"]:@{};
        userId=[probe[@"currentUserId"] isKindOfClass:NSString.class]?probe[@"currentUserId"]:@"";
    }
    if(userId.length==0)return;

    NSArray<NSString *> *itemKeys=@[@"posts",@"replies",@"reposts"];
    NSArray<NSString *> *cursorKeys=@[@"postsCursor",@"repliesCursor",@"repostsCursor"];
    NSArray<NSString *> *hasMoreKeys=@[@"postsHasMore",@"repliesHasMore",@"repostsHasMore"];
    NSArray<NSString *> *loadingKeys=@[@"postsMoreLoading",@"repliesMoreLoading",@"repostsMoreLoading"];
    NSString *itemKey=itemKeys[(NSUInteger)tab];
    NSString *cursorKey=cursorKeys[(NSUInteger)tab];
    NSString *hasMoreKey=hasMoreKeys[(NSUInteger)tab];
    NSString *loadingKey=loadingKeys[(NSUInteger)tab];
    NSString *cursor=[data[cursorKey] isKindOfClass:NSString.class]?data[cursorKey]:@"";

    NSMutableDictionary *initial=[data mutableCopy];
    initial[loadingKey]=@YES;
    [profile applyProfileData:initial];

    NSString *script=[self sx238_pageScriptForTab:tab userId:userId cursor:cursor];
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
                NSArray *incoming=[dict[@"items"] isKindOfClass:NSArray.class]?dict[@"items"]:@[];
                NSString *nextCursor=[dict[@"nextCursor"] isKindOfClass:NSString.class]?dict[@"nextCursor"]:@"";
                NSDictionary *current=[strongProfile.profileData isKindOfClass:NSDictionary.class]?strongProfile.profileData:@{};
                NSArray *existing=[current[itemKey] isKindOfClass:NSArray.class]?current[itemKey]:@[];
                NSMutableArray *mergedItems=[NSMutableArray arrayWithArray:existing];
                NSMutableSet *seen=[NSMutableSet set];
                for(id obj in existing){ if([obj isKindOfClass:NSDictionary.class]){ NSString *iid=[obj[@"id"] isKindOfClass:NSString.class]?obj[@"id"]:@""; if(iid.length)[seen addObject:iid]; } }
                for(id obj in incoming){ if(![obj isKindOfClass:NSDictionary.class])continue; NSString *iid=[obj[@"id"] isKindOfClass:NSString.class]?obj[@"id"]:@""; if(iid.length&&[seen containsObject:iid])continue; if(iid.length)[seen addObject:iid]; [mergedItems addObject:obj]; }
                NSMutableDictionary *merged=[current mutableCopy];
                merged[itemKey]=mergedItems;
                merged[cursorKey]=nextCursor;
                merged[hasMoreKey]=@(nextCursor.length>0);
                merged[loadingKey]=@NO;
                [[DiagnosticsStore shared] addEvent:@"Native profile pagination loaded" detail:[NSString stringWithFormat:@"tab=%ld attempts=%ld added=%lu total=%lu hasMore=%@",(long)tab,(long)attempt,(unsigned long)(mergedItems.count-existing.count),(unsigned long)mergedItems.count,nextCursor.length?@"YES":@"NO"] url:webView.URL];
                dispatch_async(dispatch_get_main_queue(),^{ [strongProfile applyProfileData:merged]; });
                poll=nil;return;
            }
            BOOL explicitError=[state isEqualToString:@"error"];
            if(explicitError||attempt>=24){
                NSDictionary *current=[strongProfile.profileData isKindOfClass:NSDictionary.class]?strongProfile.profileData:@{};
                NSMutableDictionary *merged=[current mutableCopy];
                merged[loadingKey]=@NO;
                NSString *stage=[dict[@"stage"] isKindOfClass:NSString.class]?dict[@"stage"]:(error?@"evaluate":@"timeout");
                [[DiagnosticsStore shared] addEvent:@"Native profile pagination failed" detail:[NSString stringWithFormat:@"tab=%ld attempts=%ld stage=%@",(long)tab,(long)attempt,stage] url:webView.URL];
                dispatch_async(dispatch_get_main_queue(),^{ [strongProfile applyProfileData:merged]; });
                poll=nil;return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),poll);
        }];
    };
    poll();
}

@end
