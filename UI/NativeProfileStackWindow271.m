#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX271DisplayLimitsKey;
static char SX271InstalledPanKey;
static char SX271LastRequestTimesKey;

typedef void (*SX271ViewDidLoadIMP)(id, SEL);
static SX271ViewDidLoadIMP SX271PreviousViewDidLoadIMP = NULL;

typedef void (*SX271ReloadIMP)(id, SEL, UIStackView *);
static SX271ReloadIMP SX271PreviousReloadIMP = NULL;

@interface NativeProfileViewController (NativeProfileStackWindow271Private)
- (UIView *)sx223_contentView;
- (UIStackView *)sx223_postsStackInContent:(UIView *)content;
- (UIView *)postViewForPost:(NSDictionary *)post;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NSInteger SX271SelectedTab(NativeProfileViewController *profile) {
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

static UIScrollView *SX271ScrollView(NativeProfileViewController *profile) {
    @try {
        id value = [profile valueForKey:@"scrollView"];
        return [value isKindOfClass:UIScrollView.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSMutableDictionary *SX271DisplayLimits(NativeProfileViewController *profile) {
    NSMutableDictionary *limits = objc_getAssociatedObject(profile, &SX271DisplayLimitsKey);
    if (!limits) {
        limits = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(profile, &SX271DisplayLimitsKey, limits, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return limits;
}

static NSInteger SX271LimitForTab(NativeProfileViewController *profile, NSInteger tab) {
    if (tab < 0 || tab > 2) return 0;
    NSNumber *stored = SX271DisplayLimits(profile)[@(tab)];
    NSInteger value = [stored respondsToSelector:@selector(integerValue)] ? stored.integerValue : 0;
    return value > 0 ? value : 15;
}

static void SX271SetLimit(NativeProfileViewController *profile, NSInteger tab, NSInteger value) {
    if (tab < 0 || tab > 2) return;
    SX271DisplayLimits(profile)[@(tab)] = @(MAX(15, value));
}

static NSMutableDictionary *SX271LastRequestTimes(NativeProfileViewController *profile) {
    NSMutableDictionary *times = objc_getAssociatedObject(profile, &SX271LastRequestTimesKey);
    if (!times) {
        times = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(profile, &SX271LastRequestTimesKey, times, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return times;
}

static BOOL SX271NearBottom(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:UIScrollView.class]) return NO;
    CGFloat contentHeight = scrollView.contentSize.height;
    if (contentHeight <= 0.0) return NO;
    CGFloat visibleBottom = scrollView.contentOffset.y + CGRectGetHeight(scrollView.bounds);
    return visibleBottom >= contentHeight - 1200.0;
}

static void SX271RemoveTrailingButtons(UIStackView *stack) {
    while (stack.arrangedSubviews.count > 0) {
        UIView *last = stack.arrangedSubviews.lastObject;
        if (![last isKindOfClass:UIButton.class]) break;
        [stack removeArrangedSubview:last];
        [last removeFromSuperview];
    }
}

static NSArray *SX271ItemsForTab(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return @[];
    NSArray<NSString *> *keys = @[@"posts", @"replies", @"reposts"];
    id value = data[keys[(NSUInteger)tab]];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static BOOL SX271HasMore(NSDictionary *data, NSInteger tab, NSArray *items) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (items.count > 0);
}

static BOOL SX271MoreLoading(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static BOOL SX271InitialLoading(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsLoading", @"repliesLoading", @"repostsLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static void SX271MaybeRequestMore(NativeProfileViewController *profile,
                                  NSInteger tab,
                                  NSDictionary *data,
                                  NSArray *items,
                                  NSInteger visibleLimit) {
    if (!SX271HasMore(data, tab, items) || SX271MoreLoading(data, tab)) return;
    if (visibleLimit + 10 < (NSInteger)items.count) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSNumber *previous = SX271LastRequestTimes(profile)[@(tab)];
    if (previous && now - previous.doubleValue < 1.5) return;
    SX271LastRequestTimes(profile)[@(tab)] = @(now);
    [profile sx238_loadMoreTimeline:nil];
}

static void SX271AppendLocalItems(NativeProfileViewController *profile,
                                  UIStackView *stack,
                                  NSArray *items,
                                  NSInteger oldLimit,
                                  NSInteger newLimit) {
    if (![stack isKindOfClass:UIStackView.class]) return;
    SX271RemoveTrailingButtons(stack);
    NSUInteger start = MIN((NSUInteger)MAX(0, oldLimit), items.count);
    NSUInteger end = MIN((NSUInteger)MAX(0, newLimit), items.count);
    for (NSUInteger idx = start; idx < end; idx++) {
        id item = items[idx];
        if (![item isKindOfClass:NSDictionary.class]) continue;
        [stack addArrangedSubview:[profile postViewForPost:(NSDictionary *)item]];
    }
    UIView *content = [profile sx223_contentView];
    [content setNeedsLayout];
}

static UIButton *SX271HiddenFooter(id selfObject, SEL _cmd, NSString *title, SEL action, BOOL enabled) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.hidden = YES;
    button.userInteractionEnabled = NO;
    button.accessibilityIdentifier = @"sx.profile.stackwindow.footer";
    return button;
}

static void SX271ReloadPostsStack(id selfObject, SEL _cmd, UIStackView *postsStack) {
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    if (![postsStack isKindOfClass:UIStackView.class]) {
        if (SX271PreviousReloadIMP) SX271PreviousReloadIMP(selfObject, _cmd, postsStack);
        return;
    }

    for (UIView *view in [postsStack.arrangedSubviews copy]) {
        [postsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSInteger tab = SX271SelectedTab(profile);
    if (tab < 0 || tab > 2) {
        if (SX271PreviousReloadIMP) SX271PreviousReloadIMP(selfObject, _cmd, postsStack);
        return;
    }

    NSArray *items = SX271ItemsForTab(data, tab);
    NSInteger limit = SX271LimitForTab(profile, tab);
    NSUInteger renderCount = MIN(items.count, (NSUInteger)MAX(0, limit));
    NSInteger added = 0;
    for (NSUInteger idx = 0; idx < renderCount; idx++) {
        id item = items[idx];
        if (![item isKindOfClass:NSDictionary.class]) continue;
        [postsStack addArrangedSubview:[profile postViewForPost:(NSDictionary *)item]];
        added++;
    }

    if (added == 0) {
        NSArray<NSString *> *loadingTexts = @[@"Xからポストを読み込み中…", @"Xから返信を読み込み中…", @"Xからリポストを読み込み中…"];
        NSArray<NSString *> *emptyTexts = @[@"通常ポストはありません", @"返信はありません", @"リポストはありません"];
        UILabel *empty = [UILabel new];
        empty.font = [UIFont systemFontOfSize:14];
        empty.textColor = UIColor.secondaryLabelColor;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        empty.text = SX271InitialLoading(data, tab) ? loadingTexts[(NSUInteger)tab] : emptyTexts[(NSUInteger)tab];
        [postsStack addArrangedSubview:empty];
        [empty.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    }
}

@implementation NativeProfileViewController (NativeProfileStackWindow271)

- (NSInteger)sx271_displayLimitForTab:(NSInteger)tab {
    return SX271LimitForTab(self, tab);
}

- (void)sx271_handleProfileScroll:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan &&
        gesture.state != UIGestureRecognizerStateChanged &&
        gesture.state != UIGestureRecognizerStateEnded) return;

    UIScrollView *scrollView = SX271ScrollView(self);
    if (!SX271NearBottom(scrollView)) return;

    NSInteger tab = SX271SelectedTab(self);
    if (tab < 0 || tab > 2) return;

    NSDictionary *data = [self.profileData isKindOfClass:NSDictionary.class] ? self.profileData : @{};
    NSArray *items = SX271ItemsForTab(data, tab);
    if (items.count == 0) return;

    NSInteger oldLimit = SX271LimitForTab(self, tab);
    NSInteger newLimit = oldLimit;
    if ((NSUInteger)oldLimit < items.count) {
        newLimit = MIN((NSInteger)items.count, oldLimit + 10);
        SX271SetLimit(self, tab, newLimit);
        UIView *content = [self sx223_contentView];
        UIStackView *stack = [self sx223_postsStackInContent:content];
        SX271AppendLocalItems(self, stack, items, oldLimit, newLimit);
    }

    SX271MaybeRequestMore(self, tab, data, items, newLimit);
}

- (void)sx271_installScrollTriggerIfNeeded {
    UIScrollView *scrollView = SX271ScrollView(self);
    if (!scrollView) return;
    UIGestureRecognizer *pan = scrollView.panGestureRecognizer;
    if (objc_getAssociatedObject(pan, &SX271InstalledPanKey)) return;
    [pan addTarget:self action:@selector(sx271_handleProfileScroll:)];
    objc_setAssociatedObject(pan, &SX271InstalledPanKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static void SX271ViewDidLoad(id selfObject, SEL _cmd) {
    if (SX271PreviousViewDidLoadIMP) SX271PreviousViewDidLoadIMP(selfObject, _cmd);
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    [profile sx271_installScrollTriggerIfNeeded];
}

@interface SX271StackWindowInstaller : NSObject
@end

@implementation SX271StackWindowInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"NativeProfileViewController");
        if (!cls) return;

        SEL reloadSEL = NSSelectorFromString(@"sx223_reloadPostsStack:");
        Method reloadMethod = class_getInstanceMethod(cls, reloadSEL);
        if (reloadMethod) {
            IMP current = method_getImplementation(reloadMethod);
            if (current != (IMP)SX271ReloadPostsStack) {
                SX271PreviousReloadIMP = (SX271ReloadIMP)current;
                class_replaceMethod(cls, reloadSEL, (IMP)SX271ReloadPostsStack, method_getTypeEncoding(reloadMethod));
            }
        }

        SEL footerSEL = NSSelectorFromString(@"sx238_moreButtonWithTitle:action:enabled:");
        Method footerMethod = class_getInstanceMethod(cls, footerSEL);
        if (footerMethod) {
            class_replaceMethod(cls, footerSEL, (IMP)SX271HiddenFooter, method_getTypeEncoding(footerMethod));
        }

        Method viewDidLoadMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (viewDidLoadMethod) {
            IMP current = method_getImplementation(viewDidLoadMethod);
            if (current != (IMP)SX271ViewDidLoad) {
                SX271PreviousViewDidLoadIMP = (SX271ViewDidLoadIMP)current;
                class_replaceMethod(cls, @selector(viewDidLoad), (IMP)SX271ViewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
            }
        }
    });
}

@end
