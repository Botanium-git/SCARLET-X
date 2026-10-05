#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX272DisplayLimitsKey;
static char SX272InstalledPanKey;
static char SX272LastRequestTimesKey;
static char SX272LastAppendTimesKey;

typedef void (*SX272ViewDidLoadIMP)(id, SEL);
static SX272ViewDidLoadIMP SX272PreviousViewDidLoadIMP = NULL;

typedef void (*SX272ReloadIMP)(id, SEL, UIStackView *);
static SX272ReloadIMP SX272PreviousReloadIMP = NULL;

@interface NativeProfileViewController (NativeProfileStackWindow272Private)
- (UIView *)sx223_contentView;
- (UIStackView *)sx223_postsStackInContent:(UIView *)content;
- (UIView *)postViewForPost:(NSDictionary *)post;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NSInteger SX272SelectedTab(NativeProfileViewController *profile) {
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

static UIScrollView *SX272ScrollView(NativeProfileViewController *profile) {
    @try {
        id value = [profile valueForKey:@"scrollView"];
        return [value isKindOfClass:UIScrollView.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSMutableDictionary *SX272Dictionary(NativeProfileViewController *profile, const void *key) {
    NSMutableDictionary *dict = objc_getAssociatedObject(profile, key);
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(profile, key, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}

static NSInteger SX272LimitForTab(NativeProfileViewController *profile, NSInteger tab) {
    if (tab < 0 || tab > 2) return 0;
    NSNumber *stored = SX272Dictionary(profile, &SX272DisplayLimitsKey)[@(tab)];
    NSInteger value = [stored respondsToSelector:@selector(integerValue)] ? stored.integerValue : 0;
    return value > 0 ? value : 15;
}

static void SX272SetLimit(NativeProfileViewController *profile, NSInteger tab, NSInteger value) {
    if (tab < 0 || tab > 2) return;
    SX272Dictionary(profile, &SX272DisplayLimitsKey)[@(tab)] = @(MAX(15, value));
}

static BOOL SX272NearBottom(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:UIScrollView.class]) return NO;
    CGFloat contentHeight = scrollView.contentSize.height;
    if (contentHeight <= 0.0) return NO;
    CGFloat visibleBottom = scrollView.contentOffset.y + CGRectGetHeight(scrollView.bounds);
    return visibleBottom >= contentHeight - 2600.0;
}

static void SX272RemoveTrailingButtons(UIStackView *stack) {
    while (stack.arrangedSubviews.count > 0) {
        UIView *last = stack.arrangedSubviews.lastObject;
        if (![last isKindOfClass:UIButton.class]) break;
        [stack removeArrangedSubview:last];
        [last removeFromSuperview];
    }
}

static NSArray *SX272ItemsForTab(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return @[];
    NSArray<NSString *> *keys = @[@"posts", @"replies", @"reposts"];
    id value = data[keys[(NSUInteger)tab]];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static BOOL SX272HasMore(NSDictionary *data, NSInteger tab, NSArray *items) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (items.count > 0);
}

static BOOL SX272MoreLoading(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static BOOL SX272InitialLoading(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsLoading", @"repliesLoading", @"repostsLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static void SX272MaybeRequestMore(NativeProfileViewController *profile,
                                  NSInteger tab,
                                  NSDictionary *data,
                                  NSArray *items,
                                  NSInteger visibleLimit) {
    if (!SX272HasMore(data, tab, items) || SX272MoreLoading(data, tab)) return;
    if (visibleLimit + 20 < (NSInteger)items.count) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *times = SX272Dictionary(profile, &SX272LastRequestTimesKey);
    NSNumber *previous = times[@(tab)];
    if (previous && now - previous.doubleValue < 1.5) return;
    times[@(tab)] = @(now);
    [profile sx238_loadMoreTimeline:nil];
}

static BOOL SX272CanAppendNow(NativeProfileViewController *profile, NSInteger tab) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *times = SX272Dictionary(profile, &SX272LastAppendTimesKey);
    NSNumber *previous = times[@(tab)];
    if (previous && now - previous.doubleValue < 0.10) return NO;
    times[@(tab)] = @(now);
    return YES;
}

static void SX272AppendLocalItems(NativeProfileViewController *profile,
                                  UIStackView *stack,
                                  NSArray *items,
                                  NSInteger oldLimit,
                                  NSInteger newLimit) {
    if (![stack isKindOfClass:UIStackView.class]) return;
    SX272RemoveTrailingButtons(stack);
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

static UIButton *SX272HiddenFooter(id selfObject, SEL _cmd, NSString *title, SEL action, BOOL enabled) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.hidden = YES;
    button.userInteractionEnabled = NO;
    button.accessibilityIdentifier = @"sx.profile.stackwindow.footer";
    return button;
}

static void SX272ReloadPostsStack(id selfObject, SEL _cmd, UIStackView *postsStack) {
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    if (![postsStack isKindOfClass:UIStackView.class]) {
        if (SX272PreviousReloadIMP) SX272PreviousReloadIMP(selfObject, _cmd, postsStack);
        return;
    }

    for (UIView *view in [postsStack.arrangedSubviews copy]) {
        [postsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSInteger tab = SX272SelectedTab(profile);
    if (tab < 0 || tab > 2) {
        if (SX272PreviousReloadIMP) SX272PreviousReloadIMP(selfObject, _cmd, postsStack);
        return;
    }

    NSArray *items = SX272ItemsForTab(data, tab);
    NSInteger limit = SX272LimitForTab(profile, tab);
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
        empty.text = SX272InitialLoading(data, tab) ? loadingTexts[(NSUInteger)tab] : emptyTexts[(NSUInteger)tab];
        [postsStack addArrangedSubview:empty];
        [empty.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    }
}

@implementation NativeProfileViewController (NativeProfileStackWindow272)

- (NSInteger)sx271_displayLimitForTab:(NSInteger)tab {
    return SX272LimitForTab(self, tab);
}

- (void)sx272_handleProfileScroll:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan &&
        gesture.state != UIGestureRecognizerStateChanged &&
        gesture.state != UIGestureRecognizerStateEnded) return;

    UIScrollView *scrollView = SX272ScrollView(self);
    if (!SX272NearBottom(scrollView)) return;

    NSInteger tab = SX272SelectedTab(self);
    if (tab < 0 || tab > 2) return;

    NSDictionary *data = [self.profileData isKindOfClass:NSDictionary.class] ? self.profileData : @{};
    NSArray *items = SX272ItemsForTab(data, tab);
    if (items.count == 0) return;

    NSInteger oldLimit = SX272LimitForTab(self, tab);
    NSInteger newLimit = oldLimit;
    if ((NSUInteger)oldLimit < items.count && SX272CanAppendNow(self, tab)) {
        newLimit = MIN((NSInteger)items.count, oldLimit + 2);
        SX272SetLimit(self, tab, newLimit);
        UIView *content = [self sx223_contentView];
        UIStackView *stack = [self sx223_postsStackInContent:content];
        SX272AppendLocalItems(self, stack, items, oldLimit, newLimit);
    }

    SX272MaybeRequestMore(self, tab, data, items, newLimit);
}

- (void)sx272_installScrollTriggerIfNeeded {
    UIScrollView *scrollView = SX272ScrollView(self);
    if (!scrollView) return;
    UIGestureRecognizer *pan = scrollView.panGestureRecognizer;
    if (objc_getAssociatedObject(pan, &SX272InstalledPanKey)) return;
    [pan addTarget:self action:@selector(sx272_handleProfileScroll:)];
    objc_setAssociatedObject(pan, &SX272InstalledPanKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static void SX272ViewDidLoad(id selfObject, SEL _cmd) {
    if (SX272PreviousViewDidLoadIMP) SX272PreviousViewDidLoadIMP(selfObject, _cmd);
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    [profile sx272_installScrollTriggerIfNeeded];
}

@interface SX272StackWindowInstaller : NSObject
@end

@implementation SX272StackWindowInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"NativeProfileViewController");
        if (!cls) return;

        SEL reloadSEL = NSSelectorFromString(@"sx223_reloadPostsStack:");
        Method reloadMethod = class_getInstanceMethod(cls, reloadSEL);
        if (reloadMethod) {
            IMP current = method_getImplementation(reloadMethod);
            if (current != (IMP)SX272ReloadPostsStack) {
                SX272PreviousReloadIMP = (SX272ReloadIMP)current;
                class_replaceMethod(cls, reloadSEL, (IMP)SX272ReloadPostsStack, method_getTypeEncoding(reloadMethod));
            }
        }

        SEL footerSEL = NSSelectorFromString(@"sx238_moreButtonWithTitle:action:enabled:");
        Method footerMethod = class_getInstanceMethod(cls, footerSEL);
        if (footerMethod) {
            class_replaceMethod(cls, footerSEL, (IMP)SX272HiddenFooter, method_getTypeEncoding(footerMethod));
        }

        Method viewDidLoadMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (viewDidLoadMethod) {
            IMP current = method_getImplementation(viewDidLoadMethod);
            if (current != (IMP)SX272ViewDidLoad) {
                SX272PreviousViewDidLoadIMP = (SX272ViewDidLoadIMP)current;
                class_replaceMethod(cls, @selector(viewDidLoad), (IMP)SX272ViewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
            }
        }
    });
}

@end
