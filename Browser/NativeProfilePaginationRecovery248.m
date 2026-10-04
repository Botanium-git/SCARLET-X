#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface SX248WeakBox : NSObject
@property(nonatomic, weak) id value;
@end
@implementation SX248WeakBox
@end

static char SX248ProfileBoxKey;
static char SX248WebViewBoxKey;
static char SX248ObserverKey;
static char SX248GenerationKey;

typedef void (*SX248LoadMoreIMP)(id, SEL, NSInteger, NativeProfileViewController *, WKWebView *);
static SX248LoadMoreIMP SX248PreviousLoadMoreIMP = NULL;

static NSInteger SX248Generation(id owner) {
    NSNumber *n = objc_getAssociatedObject(owner, &SX248GenerationKey);
    return [n respondsToSelector:@selector(integerValue)] ? n.integerValue : 0;
}

static NSInteger SX248AdvanceGeneration(id owner) {
    NSInteger next = SX248Generation(owner) + 1;
    objc_setAssociatedObject(owner, &SX248GenerationKey, @(next), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return next;
}

static BOOL SX248ClearLoadingFlags(NativeProfileViewController *profile) {
    if (![profile isKindOfClass:NativeProfileViewController.class]) return NO;
    NSDictionary *current = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSMutableDictionary *next = [current mutableCopy];
    BOOL changed = NO;
    for (NSString *key in @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"]) {
        if ([next[key] respondsToSelector:@selector(boolValue)] && [next[key] boolValue]) {
            next[key] = @NO;
            changed = YES;
        }
    }
    if (changed) [profile applyProfileData:next];
    return changed;
}

static void SX248ClearWebLoadingSlots(WKWebView *webView) {
    if (![webView isKindOfClass:WKWebView.class]) return;
    NSString *script = @"(function(){for(var i=0;i<3;i++){var k='__scarletXProfilePage238_'+i;try{if(window[k]&&window[k].state==='loading')delete window[k];}catch(_){}}return true;})()";
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void SX248InstallObserverIfNeeded(BrowserViewController *owner) {
    if (objc_getAssociatedObject(owner, &SX248ObserverKey)) return;
    __weak BrowserViewController *weakOwner = owner;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                 object:nil
                                                                  queue:NSOperationQueue.mainQueue
                                                             usingBlock:^(__unused NSNotification *note) {
        BrowserViewController *strongOwner = weakOwner;
        if (!strongOwner) return;
        SX248WeakBox *profileBox = objc_getAssociatedObject(strongOwner, &SX248ProfileBoxKey);
        SX248WeakBox *webBox = objc_getAssociatedObject(strongOwner, &SX248WebViewBoxKey);
        NativeProfileViewController *profile = [profileBox.value isKindOfClass:NativeProfileViewController.class] ? profileBox.value : nil;
        WKWebView *webView = [webBox.value isKindOfClass:WKWebView.class] ? webBox.value : nil;
        BOOL cleared = SX248ClearLoadingFlags(profile);
        SX248ClearWebLoadingSlots(webView);
        SX248AdvanceGeneration(strongOwner);
        if (cleared) {
            [[DiagnosticsStore shared] addEvent:@"Native profile pagination recovered after foreground"
                                         detail:@"cleared MoreLoading flags and JS loading slots"
                                            url:webView.URL];
        }
    }];
    objc_setAssociatedObject(owner, &SX248ObserverKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SX248LoadMore(id selfObject, SEL _cmd, NSInteger tab, NativeProfileViewController *profile, WKWebView *webView) {
    BrowserViewController *owner = (BrowserViewController *)selfObject;
    SX248InstallObserverIfNeeded(owner);

    SX248WeakBox *profileBox = objc_getAssociatedObject(owner, &SX248ProfileBoxKey);
    if (!profileBox) {
        profileBox = [SX248WeakBox new];
        objc_setAssociatedObject(owner, &SX248ProfileBoxKey, profileBox, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    profileBox.value = profile;

    SX248WeakBox *webBox = objc_getAssociatedObject(owner, &SX248WebViewBoxKey);
    if (!webBox) {
        webBox = [SX248WeakBox new];
        objc_setAssociatedObject(owner, &SX248WebViewBoxKey, webBox, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    webBox.value = webView;

    NSInteger generation = SX248AdvanceGeneration(owner);
    if (SX248PreviousLoadMoreIMP) SX248PreviousLoadMoreIMP(selfObject, _cmd, tab, profile, webView);

    __weak BrowserViewController *weakOwner = owner;
    __weak NativeProfileViewController *weakProfile = profile;
    __weak WKWebView *weakWebView = webView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BrowserViewController *strongOwner = weakOwner;
        NativeProfileViewController *strongProfile = weakProfile;
        WKWebView *strongWebView = weakWebView;
        if (!strongOwner || !strongProfile) return;
        if (SX248Generation(strongOwner) != generation) return;
        BOOL cleared = SX248ClearLoadingFlags(strongProfile);
        if (!cleared) return;
        SX248ClearWebLoadingSlots(strongWebView);
        SX248AdvanceGeneration(strongOwner);
        [[DiagnosticsStore shared] addEvent:@"Native profile pagination watchdog recovered"
                                     detail:[NSString stringWithFormat:@"tab=%ld timeout=20s", (long)tab]
                                        url:strongWebView.URL];
    });
}

@implementation BrowserViewController (NativeProfilePaginationRecovery248)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;
        SEL sel = NSSelectorFromString(@"sx238_loadMoreTab:profile:sourceWebView:");
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) return;
        IMP current = method_getImplementation(method);
        if (current == (IMP)SX248LoadMore) return;
        SX248PreviousLoadMoreIMP = (SX248LoadMoreIMP)current;
        class_replaceMethod(cls, sel, (IMP)SX248LoadMore, method_getTypeEncoding(method));
    });
}

@end
