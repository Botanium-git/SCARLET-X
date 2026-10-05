#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <objc/runtime.h>

typedef NSString *(*SX256ScriptOneArgIMP)(id, SEL, NSString *);
typedef NSString *(*SX256PageScriptIMP)(id, SEL, NSInteger, NSString *, NSString *);

static SX256ScriptOneArgIMP SX256PostsIMP = NULL;
static SX256ScriptOneArgIMP SX256RepliesIMP = NULL;
static SX256ScriptOneArgIMP SX256RepostsIMP = NULL;
static SX256PageScriptIMP SX256PageIMP = NULL;

static NSString *SX256QuoteHelper(void) {
    return @"function sx256QuoteFor(tweet){try{"
    "var raw=tweet&&tweet.quoted_status_result&&tweet.quoted_status_result.result;"
    "if(!raw){var lg=tweet&&tweet.legacy;raw=lg&&lg.quoted_status_result&&lg.quoted_status_result.result;}"
    "if(!raw)return null;"
    "if(raw.__typename==='TweetWithVisibilityResults'&&raw.tweet)raw=raw.tweet;"
    "if(raw.result&&raw.result.__typename==='Tweet')raw=raw.result;"
    "if(!raw||raw.__typename!=='Tweet')return null;"
    "var l=raw.legacy&&typeof raw.legacy==='object'?raw.legacy:null;if(!l)return null;"
    "var u=raw.core&&raw.core.user_results&&raw.core.user_results.result;"
    "if(u&&u.__typename==='UserUnavailable')u=null;"
    "var ul=u&&u.legacy&&typeof u.legacy==='object'?u.legacy:{};"
    "var text=String(val(l,'full_text')||''),range=l.display_text_range;"
    "if(Array.isArray(range)&&range.length>=2&&typeof range[0]==='number'&&typeof range[1]==='number'&&range[0]>=0&&range[1]>=range[0]&&range[1]<=text.length)text=text.slice(range[0],range[1]);"
    "var media=mediaFor(l);"
    "return {id:String(val(raw,'rest_id')||val(l,'id_str')||''),text:text,createdAt:String(val(l,'created_at')||''),authorName:String(val(ul,'name')||''),authorHandle:String(val(ul,'screen_name')||''),authorAvatarURL:String(val(ul,'profile_image_url_https')||val(ul,'profile_image_url')||''),media:media,mediaURL:media.length?String(media[0].previewURL||''):''};"
    "}catch(_){return null;}}";
}

static NSString *SX256EnsureMediaHelper(NSString *script) {
    if ([script rangeOfString:@"function mediaFor("].location != NSNotFound) return script;
    NSString *helper = @"function mediaFor(legacy){var raw=legacy&&legacy.extended_entities&&Array.isArray(legacy.extended_entities.media)?legacy.extended_entities.media:(legacy&&legacy.entities&&Array.isArray(legacy.entities.media)?legacy.entities.media:[]),out=[];for(var i=0;i<raw.length;i++){var m=raw[i];if(!m)continue;var type=String(val(m,'type')||''),preview=String(val(m,'media_url_https')||val(m,'media_url')||'');if(!preview)continue;var oi=m.original_info&&typeof m.original_info==='object'?m.original_info:null;var w=oi&&Number(oi.width)||0,h=oi&&Number(oi.height)||0,videoURL='',vi=m.video_info&&typeof m.video_info==='object'?m.video_info:null,vars=vi&&Array.isArray(vi.variants)?vi.variants:[],best=-1;for(var j=0;j<vars.length;j++){var vr=vars[j];if(!vr||String(val(vr,'content_type')||'')!=='video/mp4')continue;var bit=Number(val(vr,'bitrate')||0),u=String(val(vr,'url')||'');if(u&&bit>=best){best=bit;videoURL=u;}}out.push({type:type,previewURL:preview,videoURL:videoURL,width:w,height:h});}return out;}";
    NSRange anchor = [script rangeOfString:@"function normalize(result){"];
    if (anchor.location == NSNotFound) return script;
    NSMutableString *patched = [script mutableCopy];
    [patched insertString:helper atIndex:anchor.location];
    return patched;
}

static NSString *SX256PatchQuoteData(NSString *script) {
    if (![script isKindOfClass:NSString.class] || script.length == 0) return script;
    NSString *patched = SX256EnsureMediaHelper(script);
    if ([patched rangeOfString:@"function sx256QuoteFor("].location == NSNotFound) {
        NSRange anchor = [patched rangeOfString:@"function normalize(result){"];
        if (anchor.location == NSNotFound) return patched;
        NSMutableString *mutable = [patched mutableCopy];
        [mutable insertString:SX256QuoteHelper() atIndex:anchor.location];
        patched = mutable;
    }

    NSString *needle = @"favoriteCount:Number(val(legacy,'favorite_count')||0)";
    NSString *replacement = @"favoriteCount:Number(val(legacy,'favorite_count')||0),quoted:sx256QuoteFor(tweet)";
    return [patched stringByReplacingOccurrencesOfString:needle withString:replacement];
}

static NSString *SX256Posts(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX256PostsIMP ? SX256PostsIMP(selfObject, _cmd, userId) : nil;
    return SX256PatchQuoteData(script);
}

static NSString *SX256Replies(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX256RepliesIMP ? SX256RepliesIMP(selfObject, _cmd, userId) : nil;
    return SX256PatchQuoteData(script);
}

static NSString *SX256Reposts(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX256RepostsIMP ? SX256RepostsIMP(selfObject, _cmd, userId) : nil;
    return SX256PatchQuoteData(script);
}

static NSString *SX256Page(id selfObject, SEL _cmd, NSInteger tab, NSString *userId, NSString *cursor) {
    NSString *script = SX256PageIMP ? SX256PageIMP(selfObject, _cmd, tab, userId, cursor) : nil;
    return SX256PatchQuoteData(script);
}

static void SX256ReplaceOneArg(Class cls, SEL selector, IMP replacement, SX256ScriptOneArgIMP *storage) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == replacement) return;
    *storage = (SX256ScriptOneArgIMP)current;
    class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
}

@interface BrowserViewController (NativeProfileQuotes256)
@end

@implementation BrowserViewController (NativeProfileQuotes256)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;
        SX256ReplaceOneArg(cls, NSSelectorFromString(@"sx_211_internalPostsScriptForUserId:"), (IMP)SX256Posts, &SX256PostsIMP);
        SX256ReplaceOneArg(cls, NSSelectorFromString(@"sx_229_internalRepliesScriptForUserId:"), (IMP)SX256Replies, &SX256RepliesIMP);
        SX256ReplaceOneArg(cls, NSSelectorFromString(@"sx236_repostsScriptForUserId:"), (IMP)SX256Reposts, &SX256RepostsIMP);

        SEL pageSelector = NSSelectorFromString(@"sx238_pageScriptForTab:userId:cursor:");
        Method pageMethod = class_getInstanceMethod(cls, pageSelector);
        if (pageMethod) {
            IMP current = method_getImplementation(pageMethod);
            if (current != (IMP)SX256Page) {
                SX256PageIMP = (SX256PageScriptIMP)current;
                class_replaceMethod(cls, pageSelector, (IMP)SX256Page, method_getTypeEncoding(pageMethod));
            }
        }

        [[DiagnosticsStore shared] addEvent:@"Native profile quote extraction installed"
                                     detail:@"posts,replies,reposts,pagination"
                                        url:nil];
    });
}

@end
