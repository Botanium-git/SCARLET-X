#import "BrowserViewController.h"
#import <objc/runtime.h>

typedef NSString *(*SX245StringOneArgIMP)(id, SEL, NSString *);
typedef NSString *(*SX245StringNoArgIMP)(id, SEL);
typedef NSString *(*SX245PageScriptIMP)(id, SEL, NSInteger, NSString *, NSString *);

static SX245StringOneArgIMP SX245PostsIMP = NULL;
static SX245StringOneArgIMP SX245RepliesIMP = NULL;
static SX245StringOneArgIMP SX245RepostsIMP = NULL;
static SX245PageScriptIMP SX245PageIMP = NULL;
static SX245StringOneArgIMP SX245FetchIMP = NULL;
static SX245StringNoArgIMP SX245RecoveryIMP = NULL;

static NSString *SX245PatchEndpointFactory(NSString *script) {
    if (![script isKindOfClass:NSString.class] || script.length == 0) return script;
    NSString *legacy = @"req(923288)";
    if ([script rangeOfString:legacy].location == NSNotFound) return script;

    NSString *current = @"(function(){try{return req(477802);}catch(_){try{return req(923288);}catch(__){return null;}}})()";
    return [script stringByReplacingOccurrencesOfString:legacy withString:current];
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
