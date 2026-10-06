#import "BrowserViewController.h"
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileMediaFix212)
- (NSString *)sx_212_internalPostsScriptForUserId:(NSString *)userId;
@end

@implementation BrowserViewController (NativeProfileMediaFix212)

+ (void)load {
    Class cls = self;
    SEL targetSEL = @selector(sx_211_internalPostsScriptForUserId:);
    Method target = class_getInstanceMethod(cls, targetSEL);
    Method replacement = class_getInstanceMethod(cls, @selector(sx_212_internalPostsScriptForUserId:));
    if (target && replacement) {
        class_replaceMethod(cls,
                            targetSEL,
                            method_getImplementation(replacement),
                            method_getTypeEncoding(target));
    }
}

- (NSString *)sx_212_jsonLiteral:(NSString *)value {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *array = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[\"\"]";
    if (array.length >= 2) return [array substringWithRange:NSMakeRange(1, array.length - 2)];
    return @"\"\"";
}

- (NSString *)sx_212_internalPostsScriptForUserId:(NSString *)userId {
    NSString *uid = [self sx_212_jsonLiteral:userId];
    return [NSString stringWithFormat:@"(function(){"
        "var uid=%@,KEY=\'__scarletXProfilePosts212\';"
        "function val(o,k){try{var v=o&&o[k];return(v===null||v===undefined)?'':v;}catch(_){return '';}}"
        "function normalizeMedia(legacy){"
          "var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]);"
          "var out=[];"
          "for(var i=0;i<raw.length;i++){"
            "var m=raw[i];if(!m||typeof m!=='object')continue;"
            "var type=String(val(m,'type')||'');"
            "var preview=String(val(m,'media_url_https')||val(m,'media_url')||'');"
            "if(!preview)continue;"
            "var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;"
            "var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0;"
            "var videoURL='';"
            "var vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null;"
            "var variants=vi&&Array.isArray(vi.variants)?vi.variants:[];"
            "var bestBit=-1;"
            "for(var j=0;j<variants.length;j++){"
              "var vr=variants[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;"
              "var bit=Number(val(vr,'bitrate')||0);var u=String(val(vr,'url')||'');"
              "if(u&&bit>=bestBit){bestBit=bit;videoURL=u;}"
            "}"
            "out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});"
          "}"
          "return out;"
        "}"
        "function normalize(result){"
          "var out=[],seen={};"
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
              "if(legacy.retweeted_status_id_str||tweet.retweeted_status_result||legacy.retweeted_status_result)continue;"
              "var text=String(val(legacy,'full_text')||'');"
              "var range=legacy.display_text_range;"
              "if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);"
              "var media=normalizeMedia(legacy);"
              "seen[id]=true;"
              "out.push({id:id,text:text,createdAt:String(val(legacy,'created_at')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):'',replyCount:Number(val(legacy,'reply_count')||0),retweetCount:Number(val(legacy,'retweet_count')||0),favoriteCount:Number(val(legacy,'favorite_count')||0)});"
            "}"
          "}"
          "return out;"
        "}"
        "try{"
          "var slot=window[KEY];"
          "if(slot&&slot.userId===String(uid)){if(slot.state==='success'||slot.state==='error')return slot;if(slot.state==='loading'&&Date.now()-Number(slot.startedAt||0)<7000)return slot;delete window[KEY];}"
          "var api=window.__scarletXAPI;"
          "if(!api||typeof api.withEndpoint!=='function')return {state:'waiting-api',userId:String(uid)};"
          "var q=window.webpackChunk_twitter_responsive_web,req=null;"
          "if(!Array.isArray(q))return {state:'waiting-webpack',userId:String(uid)};"
          "var marker=960000000+Math.floor(Math.random()*30000000);q.push([[marker],{},function(r){req=r;}]);"
          "if(!req)return {state:'waiting-require',userId:String(uid)};"
          "var epm=req(923288),factory=epm&&epm.Ay;"
          "if(typeof factory!=='function')return {state:'error',stage:'endpoint-factory',userId:String(uid)};"
          "var endpoint=api.withEndpoint(factory);"
          "if(!endpoint||typeof endpoint.fetchUserOriginals!=='function')return {state:'error',stage:'endpoint',userId:String(uid)};"
          "function timed(p,ms){return Promise.race([Promise.resolve(p),new Promise(function(_,reject){setTimeout(function(){reject(new Error('fetchUserOriginals-timeout'));},ms);})]);}"
          "window[KEY]={state:'loading',userId:String(uid),startedAt:Date.now()};"
          "timed(endpoint.fetchUserOriginals({userId:String(uid),count:20,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false}),5000).then(function(result){"
            "try{window[KEY]={state:'success',userId:String(uid),posts:normalize(result),finishedAt:Date.now()};}catch(e){window[KEY]={state:'error',stage:'normalize',userId:String(uid),message:String(e&&e.stack||e),finishedAt:Date.now()};}"
          "}).catch(function(e){window[KEY]={state:'error',stage:'request',userId:String(uid),message:String(e&&e.stack||e),finishedAt:Date.now()};});"
          "return window[KEY];"
        "}catch(e){return {state:'error',stage:'exception',userId:String(uid),message:String(e&&e.stack||e)};}"
      "})()", uid];
}

@end
