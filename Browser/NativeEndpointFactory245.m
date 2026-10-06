#import "BrowserViewController.h"
#import <objc/runtime.h>

typedef NSString *(*SX245StringOneArgIMP)(id, SEL, NSString *);
typedef NSString *(*SX245StringNoArgIMP)(id, SEL);
typedef NSString *(*SX245PageScriptIMP)(id, SEL, NSInteger, NSString *, NSString *);

static SX245StringOneArgIMP SX245PostsIMP = NULL;
static SX245StringOneArgIMP SX245RepliesIMP = NULL;
static SX245StringOneArgIMP SX245RepostsIMP = NULL;
static SX245StringOneArgIMP SX245MediaIMP = NULL;
static SX245PageScriptIMP SX245PageIMP = NULL;
static SX245StringOneArgIMP SX245FetchIMP = NULL;
static SX245StringNoArgIMP SX245RecoveryIMP = NULL;

static NSString *SX246DynamicEndpointResolver(void) {
    return @"(function(){"
    "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
    "function validFactory(f){try{if(typeof f!=='function'||!api||typeof api.withEndpoint!=='function')return false;var ep=api.withEndpoint(f);if(!ep)return false;return typeof ep.fetchUserOriginals==='function'||typeof ep.fetchUserReplies==='function'||typeof ep.fetchUserReposts==='function'||typeof ep.fetchUserTweetsAndReplies==='function';}catch(_){return false;}}"
    "function remember(f,id,key){window.__scarletXProfileEndpointFactory=f;window.__scarletXProfileEndpointModule=String(id||'');window.__scarletXProfileEndpointExport=String(key||'');if(!window.__scarletXDynamicEndpointPosted){window.__scarletXDynamicEndpointPosted=true;post({type:'dynamic-endpoint-resolver',stage:'matched',moduleId:String(id||''),exportKey:String(key||'')});}return {Ay:f};}"
    "try{"
      "var cached=window.__scarletXProfileEndpointFactory;if(validFactory(cached))return {Ay:cached};"
      "window.__scarletXProfileEndpointFactory=null;window.__scarletXProfileEndpointModule='';window.__scarletXProfileEndpointExport='';window.__scarletXDynamicEndpointPosted=false;"
      "var mids=[];try{mids=req&&req.m?Object.keys(req.m):[];}catch(_){mids=[];}"
      "var candidates=[];"
      "for(var i=0;i<mids.length;i++){var id=String(mids[i]),src='';try{src=String(req.m[id]||'');}catch(_){continue;}if(src.indexOf('fetchUserOriginals')<0)continue;if(src.indexOf('fetchUserReposts')<0&&src.indexOf('fetchUserReplies')<0&&src.indexOf('fetchUserTweetsAndReplies')<0)continue;candidates.push(id);if(candidates.length>=80)break;}"
      "function inspect(id){var ex=null;try{ex=req(Number(id));}catch(_){try{ex=req(id);}catch(__){return null;}}if(typeof ex==='function'&&validFactory(ex))return remember(ex,id,'<function>');if(!ex||typeof ex!=='object')return null;var ks=[];try{ks=Object.keys(ex);}catch(_){ks=[];}for(var k=0;k<ks.length;k++){var key=ks[k],v=null;try{v=ex[key];}catch(_){continue;}if(validFactory(v))return remember(v,id,key);}return null;}"
      "for(var c=0;c<candidates.length;c++){var hit=inspect(candidates[c]);if(hit)return hit;}"
      "var fallback=['477802','923288'];for(var f=0;f<fallback.length;f++){var hit2=inspect(fallback[f]);if(hit2)return hit2;}"
      "post({type:'dynamic-endpoint-resolver',stage:'not-found',candidateCount:candidates.length});return null;"
    "}catch(e){post({type:'dynamic-endpoint-resolver',stage:'exception',message:String(e&&e.stack||e)});return null;}"
    "})()";
}

static NSString *SX245PatchEndpointFactory(NSString *script) {
    if (![script isKindOfClass:NSString.class] || script.length == 0) return script;
    NSString *legacy = @"req(923288)";
    if ([script rangeOfString:legacy].location == NSNotFound) return script;
    return [script stringByReplacingOccurrencesOfString:legacy withString:SX246DynamicEndpointResolver()];
}

static NSString *SX245Posts(id self, SEL _cmd, NSString *userId) {
    NSString *script = SX245PostsIMP ? SX245PostsIMP(self, _cmd, userId) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Replies(id self, SEL _cmd, NSString *userId) {
    NSString *script = SX245RepliesIMP ? SX245RepliesIMP(self, _cmd, userId) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Reposts(id self, SEL _cmd, NSString *userId) {
    NSString *script = SX245RepostsIMP ? SX245RepostsIMP(self, _cmd, userId) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Media(id self, SEL _cmd, NSString *userId) {
    NSString *script = SX245MediaIMP ? SX245MediaIMP(self, _cmd, userId) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Page(id self, SEL _cmd, NSInteger tab, NSString *userId, NSString *cursor) {
    NSString *script = SX245PageIMP ? SX245PageIMP(self, _cmd, tab, userId, cursor) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Fetch(id self, SEL _cmd, NSString *userId) {
    NSString *script = SX245FetchIMP ? SX245FetchIMP(self, _cmd, userId) : nil;
    return SX245PatchEndpointFactory(script);
}

static NSString *SX245Recovery(id self, SEL _cmd) {
    NSString *script = SX245RecoveryIMP ? SX245RecoveryIMP(self, _cmd) : nil;
    return SX245PatchEndpointFactory(script);
}

static void SX245ReplaceOneArg(Class cls, SEL sel, IMP replacement, SX245StringOneArgIMP *storage) {
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == replacement) return;
    *storage = (SX245StringOneArgIMP)current;
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(method));
}

@implementation BrowserViewController (NativeEndpointFactory245)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;

        SX245ReplaceOneArg(cls,
                          NSSelectorFromString(@"sx_211_internalPostsScriptForUserId:"),
                          (IMP)SX245Posts,
                          &SX245PostsIMP);

        SX245ReplaceOneArg(cls,
                          NSSelectorFromString(@"sx_229_internalRepliesScriptForUserId:"),
                          (IMP)SX245Replies,
                          &SX245RepliesIMP);

        SX245ReplaceOneArg(cls,
                          NSSelectorFromString(@"sx236_repostsScriptForUserId:"),
                          (IMP)SX245Reposts,
                          &SX245RepostsIMP);

        SX245ReplaceOneArg(cls,
                          NSSelectorFromString(@"sx287_mediaScriptForUserId:"),
                          (IMP)SX245Media,
                          &SX245MediaIMP);

        Method pageMethod = class_getInstanceMethod(cls, NSSelectorFromString(@"sx238_pageScriptForTab:userId:cursor:"));
        if (pageMethod) {
            SX245PageIMP = (SX245PageScriptIMP)method_getImplementation(pageMethod);
            class_replaceMethod(cls,
                                NSSelectorFromString(@"sx238_pageScriptForTab:userId:cursor:"),
                                (IMP)SX245Page,
                                method_getTypeEncoding(pageMethod));
        }

        SX245ReplaceOneArg(cls,
                          NSSelectorFromString(@"sx_internalProfileAPI_fetchScriptForUserId:"),
                          (IMP)SX245Fetch,
                          &SX245FetchIMP);

        Method recoveryMethod = class_getInstanceMethod(cls, NSSelectorFromString(@"sx_internalProfileAPI_fiberRecoveryScript"));
        if (recoveryMethod) {
            SX245RecoveryIMP = (SX245StringNoArgIMP)method_getImplementation(recoveryMethod);
            class_replaceMethod(cls,
                                NSSelectorFromString(@"sx_internalProfileAPI_fiberRecoveryScript"),
                                (IMP)SX245Recovery,
                                method_getTypeEncoding(recoveryMethod));
        }
    });
}

@end
