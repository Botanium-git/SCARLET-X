#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <objc/runtime.h>

typedef NSString *(*SX255ScriptIMP)(id, SEL, NSString *);

static SX255ScriptIMP SX255PostsIMP = NULL;
static SX255ScriptIMP SX255RepliesIMP = NULL;
static SX255ScriptIMP SX255RepostsIMP = NULL;
static SX255ScriptIMP SX255MediaIMP = NULL;

static NSString *SX255PatchInitialCount(NSString *script) {
    if (![script isKindOfClass:NSString.class] || script.length == 0) return script;
    return [script stringByReplacingOccurrencesOfString:@"count:20,cursor:void 0"
                                             withString:@"count:50,cursor:void 0"];
}

static NSString *SX255Posts(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX255PostsIMP ? SX255PostsIMP(selfObject, _cmd, userId) : nil;
    return SX255PatchInitialCount(script);
}

static NSString *SX255Replies(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX255RepliesIMP ? SX255RepliesIMP(selfObject, _cmd, userId) : nil;
    return SX255PatchInitialCount(script);
}

static NSString *SX255Reposts(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX255RepostsIMP ? SX255RepostsIMP(selfObject, _cmd, userId) : nil;
    return SX255PatchInitialCount(script);
}

static NSString *SX255Media(id selfObject, SEL _cmd, NSString *userId) {
    NSString *script = SX255MediaIMP ? SX255MediaIMP(selfObject, _cmd, userId) : nil;
    return SX255PatchInitialCount(script);
}

static void SX255Replace(Class cls, SEL selector, IMP replacement, SX255ScriptIMP *storage) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == replacement) return;
    *storage = (SX255ScriptIMP)current;
    class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
}

@interface BrowserViewController (NativeProfileInitialCount255)
@end

@implementation BrowserViewController (NativeProfileInitialCount255)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;
        SX255Replace(cls,
                     NSSelectorFromString(@"sx_211_internalPostsScriptForUserId:"),
                     (IMP)SX255Posts,
                     &SX255PostsIMP);
        SX255Replace(cls,
                     NSSelectorFromString(@"sx_229_internalRepliesScriptForUserId:"),
                     (IMP)SX255Replies,
                     &SX255RepliesIMP);
        SX255Replace(cls,
                     NSSelectorFromString(@"sx236_repostsScriptForUserId:"),
                     (IMP)SX255Reposts,
                     &SX255RepostsIMP);

        SX255Replace(cls,
                     NSSelectorFromString(@"sx287_mediaScriptForUserId:"),
                     (IMP)SX255Media,
                     &SX255MediaIMP);

        [[DiagnosticsStore shared] addEvent:@"Native profile initial count configured"
                                     detail:@"initialCount=50 tabs=posts,replies,reposts,media paginationCount=20"
                                        url:nil];
    });
}

@end
