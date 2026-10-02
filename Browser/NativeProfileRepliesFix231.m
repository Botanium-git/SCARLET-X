#import "BrowserViewController.h"
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileRepliesFix231Private)
- (NSString *)sx_211_jsonLiteral:(NSString *)value;
- (NSString *)sx_229_internalRepliesScriptForUserId:(NSString *)userId;
@end

@implementation BrowserViewController (NativeProfileRepliesFix231)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(sx_229_internalRepliesScriptForUserId:));
        Method replacement=class_getInstanceMethod(self,@selector(sx232_internalRepliesScriptForUserId:));
        if(target&&replacement){
            class_replaceMethod(self,@selector(sx_229_internalRepliesScriptForUserId:),method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (NSString *)sx232_internalRepliesScriptForUserId:(NSString *)userId {
    NSString *uid=[self sx_211_jsonLiteral:userId];
    return [NSString stringWithFormat:@"(function(){"
      "var uid=%@,KEY='__scarletXProfileReplies232';"
      "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
      "function normalizeMedia(legacy){var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]),out=[];for(var i=0;i<raw.length;i++){var m=raw[i];if(!m)continue;var type=String(val(m,'type')||''),preview=String(val(m,'media_url_https')||val(m,'media_url')||'');if(!preview)continue;var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0,videoURL='',vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null,vars=vi&&Array.isArray(vi.variants)?vi.variants:[],best=-1;for(var j=0;j<vars.length;j++){var vr=vars[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;var bit=Number(val(vr,'bitrate')||0),u=String(val(vr,'url')||'');if(u&&bit>=best){best=bit;videoURL=u;}}out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});}return out;}"
      "function normalize(result){var out=[],seen={};function take(tweet){if(!tweet||tweet.__typename!=='Tweet')return;var legacy=tweet.legacy&&typeof tweet.legacy==='object'?tweet.legacy:null;if(!legacy)return;var id=String(val(tweet,'rest_id')||val(legacy,'id_str')||'');if(!id||seen[id])return;var owner=String(val(legacy,'user_id_str')||'');if(uid&&owner&&owner!==String(uid))return;if(legacy.retweeted_status_id_str||tweet.retweeted_status_result||legacy.retweeted_status_result)return;if(!legacy.in_reply_to_status_id_str&&!legacy.in_reply_to_user_id_str)return;var text=String(val(legacy,'full_text')||''),range=legacy.display_text_range;if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);var media=normalizeMedia(legacy);seen[id]=true;out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):'',replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0)});}function walk(v,d){if(!v||d>10)return;if(v.tweet_results&&v.tweet_results.result){take(v.tweet_results.result);return;}if(Array.isArray(v)){for(var i=0;i<v.length;i++)walk(v[i],d+1);return;}if(typeof v!=='object')return;var ks=[];try{ks=Object.keys(v);}catch(_){return;}for(var j=0;j<ks.length;j++){var k=ks[j];if(k==='feedbackInfo'||k==='clientEventInfo')continue;walk(v[k],d+1);}}walk(result,0);return out;}"
      "function timed(p,ms,label){return Promise.race([Promise.resolve(p),new Promise(function(_,reject){setTimeout(function(){reject(new Error(label));},ms);})]);}"
      "function done(list,mode){window[KEY]={state:'success',userId:String(uid),replies:list,mode:mode,finishedAt:Date.now()};return window[KEY];}"
      "function failed(stage,e){window[KEY]={state:'error',userId:String(uid),stage:stage,message:String(e&&e.stack||e||''),finishedAt:Date.now()};return window[KEY];}"
      "try{var slot=window[KEY];if(slot&&slot.userId===String(uid)){if(slot.state==='success'||slot.state==='error')return slot;if(slot.state==='loading'&&Date.now()-Number(slot.startedAt||0)<9000)return slot;delete window[KEY];}"
      "var api=window.__scarletXAPI;if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};var q=window.webpackChunk_twitter_responsive_web,req=null;if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};var marker=981000000+Math.floor(Math.random()*9000000);q.push([[marker],{},function(r){req=r;}]);if(!req)return {state:'waiting-require',userId:String(uid)};var epm=req(923288),factory=epm&&epm.Ay;if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};var endpoint=api.withEndpoint(factory);if(!endpoint)return {state:'error',stage:'endpoint',userId:String(uid)};window[KEY]={state:'loading',stage:'primary',userId:String(uid),startedAt:Date.now()};"
      "var primary=(typeof endpoint.fetchUserReplies==='function')?function(){return timed(endpoint.fetchUserReplies({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false}),3000,'fetchUserReplies-timeout');}:null;"
      "var fallback=(typeof endpoint.fetchUserTweetsAndReplies==='function')?function(){window[KEY].stage='fallback';return timed(endpoint.fetchUserTweetsAndReplies({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false}),5000,'fetchUserTweetsAndReplies-timeout');}:null;"
      "function runFallback(){if(!fallback)throw new Error('fallback-unavailable');return fallback().then(function(result){return done(normalize(result),'fetchUserTweetsAndReplies');});}"
      "var chain;if(primary){chain=primary().then(function(result){var list=normalize(result);if(list.length)return done(list,'fetchUserReplies');return runFallback();}).catch(function(){return runFallback();});}else{chain=runFallback();}"
      "Promise.resolve(chain).catch(function(e){failed('request',e);});return window[KEY];}catch(e){return failed('exception',e);}"
    "})()",uid];
}

@end
