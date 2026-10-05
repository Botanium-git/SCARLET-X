#import "NativeProfileViewController.h"
#import <objc/runtime.h>

static char SX274CacheKey;
static char SX274GenerationKey;

typedef UIView *(*SX274PostIMP)(id, SEL, NSDictionary *);
static SX274PostIMP SX274PreviousPostIMP = NULL;

typedef void (*SX274ReloadIMP)(id, SEL, UIStackView *);
static SX274ReloadIMP SX274PreviousReloadIMP = NULL;

@interface NativeProfileViewController (NativeProfilePrewarm274Private)
- (UIView *)postViewForPost:(NSDictionary *)post;
- (NSInteger)sx271_displayLimitForTab:(NSInteger)tab;
- (void)sx274_schedulePrewarmForTab:(NSInteger)tab items:(NSArray *)items startIndex:(NSUInteger)startIndex;
@end

static NSMutableDictionary<NSString *, UIView *> *SX274Cache(NativeProfileViewController *profile) {
    NSMutableDictionary *cache = objc_getAssociatedObject(profile, &SX274CacheKey);
    if (!cache) {
        cache = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(profile, &SX274CacheKey, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

static NSMutableDictionary<NSNumber *, NSNumber *> *SX274Generations(NativeProfileViewController *profile) {
    NSMutableDictionary *generations = objc_getAssociatedObject(profile, &SX274GenerationKey);
    if (!generations) {
        generations = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(profile, &SX274GenerationKey, generations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return generations;
}

static NSString *SX274PostKey(NSDictionary *post) {
    if (![post isKindOfClass:NSDictionary.class]) return @"";
    id rawID = post[@"id"];
    NSString *postID = [rawID isKindOfClass:NSString.class] ? rawID : @"";
    if (postID.length == 0) return @"";
    BOOL repost = [post[@"isRepost"] respondsToSelector:@selector(boolValue)] ? [post[@"isRepost"] boolValue] : NO;
    NSString *text = [post[@"text"] isKindOfClass:NSString.class] ? post[@"text"] : @"";
    return [NSString stringWithFormat:@"%@|%d|%lu", postID, repost ? 1 : 0, (unsigned long)text.hash];
}

static NSInteger SX274SelectedTab(NativeProfileViewController *profile) {
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

static UIScrollView *SX274ScrollView(NativeProfileViewController *profile) {
    @try {
        id value = [profile valueForKey:@"scrollView"];
        return [value isKindOfClass:UIScrollView.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static UIView *SX274PostView(id selfObject, SEL _cmd, NSDictionary *post) {
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    NSString *key = SX274PostKey(post);
    if (key.length) {
        UIView *cached = SX274Cache(profile)[key];
        if ([cached isKindOfClass:UIView.class] && cached.superview == nil) {
            [SX274Cache(profile) removeObjectForKey:key];
            return cached;
        }
        if (cached.superview != nil) [SX274Cache(profile) removeObjectForKey:key];
    }
    return SX274PreviousPostIMP ? SX274PreviousPostIMP(selfObject, _cmd, post) : nil;
}

static void SX274ReloadPostsStack(id selfObject, SEL _cmd, UIStackView *postsStack) {
    if (SX274PreviousReloadIMP) SX274PreviousReloadIMP(selfObject, _cmd, postsStack);

    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    NSInteger tab = SX274SelectedTab(profile);
    if (tab < 0 || tab > 2) return;

    NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSArray<NSString *> *keys = @[@"posts", @"replies", @"reposts"];
    NSArray *items = [data[keys[(NSUInteger)tab]] isKindOfClass:NSArray.class] ? data[keys[(NSUInteger)tab]] : @[];
    if (items.count == 0) return;

    NSInteger limit = [profile respondsToSelector:@selector(sx271_displayLimitForTab:)] ? [profile sx271_displayLimitForTab:tab] : 15;
    NSUInteger startIndex = MIN(items.count, (NSUInteger)MAX(0, limit));
    if (startIndex < items.count) [profile sx274_schedulePrewarmForTab:tab items:items startIndex:startIndex];
}

@implementation NativeProfileViewController (NativeProfilePrewarm274)

- (void)sx274_schedulePrewarmForTab:(NSInteger)tab items:(NSArray *)items startIndex:(NSUInteger)startIndex {
    if (tab < 0 || tab > 2 || ![items isKindOfClass:NSArray.class] || startIndex >= items.count) return;

    NSMutableDictionary *generations = SX274Generations(self);
    NSInteger generation = [generations[@(tab)] integerValue] + 1;
    generations[@(tab)] = @(generation);

    __weak NativeProfileViewController *weakSelf = self;
    NSArray *snapshot = [items copy];
    __block void (^prewarmNext)(NSUInteger) = nil;
    prewarmNext = ^(NSUInteger idx) {
        NativeProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) { prewarmNext = nil; return; }
        if ([SX274Generations(strongSelf)[@(tab)] integerValue] != generation) { prewarmNext = nil; return; }
        if (SX274SelectedTab(strongSelf) != tab) { prewarmNext = nil; return; }
        if (idx >= snapshot.count) { prewarmNext = nil; return; }

        UIScrollView *scrollView = SX274ScrollView(strongSelf);
        if (scrollView.tracking || scrollView.dragging || scrollView.decelerating) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (prewarmNext) prewarmNext(idx);
            });
            return;
        }

        id raw = snapshot[idx];
        if ([raw isKindOfClass:NSDictionary.class]) {
            NSDictionary *post = (NSDictionary *)raw;
            NSString *key = SX274PostKey(post);
            if (key.length && !SX274Cache(strongSelf)[key] && SX274PreviousPostIMP) {
                UIView *view = SX274PreviousPostIMP(strongSelf, @selector(postViewForPost:), post);
                if (view && view.superview == nil) SX274Cache(strongSelf)[key] = view;
            }
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (prewarmNext) prewarmNext(idx + 1);
        });
    };

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (prewarmNext) prewarmNext(startIndex);
    });
}

@end

@interface SX274PrewarmInstaller : NSObject
@end

@implementation SX274PrewarmInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            Class cls = NSClassFromString(@"NativeProfileViewController");
            if (!cls) return;

            SEL postSEL = @selector(postViewForPost:);
            Method postMethod = class_getInstanceMethod(cls, postSEL);
            if (postMethod) {
                IMP current = method_getImplementation(postMethod);
                if (current != (IMP)SX274PostView) {
                    SX274PreviousPostIMP = (SX274PostIMP)current;
                    class_replaceMethod(cls, postSEL, (IMP)SX274PostView, method_getTypeEncoding(postMethod));
                }
            }

            SEL reloadSEL = NSSelectorFromString(@"sx223_reloadPostsStack:");
            Method reloadMethod = class_getInstanceMethod(cls, reloadSEL);
            if (reloadMethod) {
                IMP current = method_getImplementation(reloadMethod);
                if (current != (IMP)SX274ReloadPostsStack) {
                    SX274PreviousReloadIMP = (SX274ReloadIMP)current;
                    class_replaceMethod(cls, reloadSEL, (IMP)SX274ReloadPostsStack, method_getTypeEncoding(reloadMethod));
                }
            }
        });
    });
}

@end
