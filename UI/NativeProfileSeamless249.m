#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX249RepostDisplayLimitKey;
static char SX249InstalledPanKey;

typedef void (*SX249ViewDidLoadIMP)(id, SEL);
static SX249ViewDidLoadIMP SX249PreviousViewDidLoadIMP = NULL;

@interface NativeProfileViewController (NativeProfileSeamless249Private)
- (UIView *)sx223_contentView;
- (UIStackView *)sx223_postsStackInContent:(UIView *)content;
- (UIView *)postViewForPost:(NSDictionary *)post;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NSInteger SX249SelectedTab(NativeProfileViewController *profile) {
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

static UIScrollView *SX249ScrollView(NativeProfileViewController *profile) {
    @try {
        id value = [profile valueForKey:@"scrollView"];
        return [value isKindOfClass:UIScrollView.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSInteger SX249RepostLimit(NativeProfileViewController *profile) {
    NSNumber *stored = objc_getAssociatedObject(profile, &SX249RepostDisplayLimitKey);
    NSInteger value = [stored respondsToSelector:@selector(integerValue)] ? stored.integerValue : 0;
    return value > 0 ? value : 8;
}

static void SX249SetRepostLimit(NativeProfileViewController *profile, NSInteger value) {
    objc_setAssociatedObject(profile, &SX249RepostDisplayLimitKey, @(MAX(8, value)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SX249RemoveTrailingButtons(UIStackView *stack) {
    while (stack.arrangedSubviews.count > 0) {
        UIView *last = stack.arrangedSubviews.lastObject;
        if (![last isKindOfClass:UIButton.class]) break;
        [stack removeArrangedSubview:last];
        [last removeFromSuperview];
    }
}

static BOOL SX249NearBottom(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:UIScrollView.class]) return NO;
    CGFloat contentHeight = scrollView.contentSize.height;
    if (contentHeight <= 0) return NO;
    CGFloat visibleBottom = scrollView.contentOffset.y + scrollView.bounds.size.height;
    return visibleBottom >= contentHeight - 900.0;
}

static void SX249AppendLocalReposts(NativeProfileViewController *profile, NSArray *items, NSInteger oldLimit, NSInteger newLimit) {
    UIView *content = [profile sx223_contentView];
    UIStackView *stack = [profile sx223_postsStackInContent:content];
    if (![stack isKindOfClass:UIStackView.class]) return;

    SX249RemoveTrailingButtons(stack);
    NSUInteger start = MIN((NSUInteger)MAX(0, oldLimit), items.count);
    NSUInteger end = MIN((NSUInteger)MAX(0, newLimit), items.count);
    for (NSUInteger idx = start; idx < end; idx++) {
        id item = items[idx];
        if (![item isKindOfClass:NSDictionary.class]) continue;
        [stack addArrangedSubview:[profile postViewForPost:(NSDictionary *)item]];
    }
    [content setNeedsLayout];
}

static UIButton *SX249HiddenFooter(id selfObject, SEL _cmd, NSString *title, SEL action, BOOL enabled) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.hidden = YES;
    button.userInteractionEnabled = NO;
    button.accessibilityIdentifier = @"sx.profile.seamless.footer";
    return button;
}

static NSInteger SX249DisplayLimit(id selfObject, SEL _cmd) {
    return SX249RepostLimit((NativeProfileViewController *)selfObject);
}

@implementation NativeProfileViewController (NativeProfileSeamless249)

- (void)sx249_handleProfileScroll:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan &&
        gesture.state != UIGestureRecognizerStateChanged &&
        gesture.state != UIGestureRecognizerStateEnded) return;

    UIScrollView *scrollView = SX249ScrollView(self);
    if (!SX249NearBottom(scrollView)) return;

    NSInteger selected = SX249SelectedTab(self);
    if (selected < 0 || selected > 2) return;

    NSDictionary *data = [self.profileData isKindOfClass:NSDictionary.class] ? self.profileData : @{};
    NSArray<NSString *> *itemKeys = @[@"posts", @"replies", @"reposts"];
    NSArray<NSString *> *hasMoreKeys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    NSArray<NSString *> *loadingKeys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];

    NSString *itemKey = itemKeys[(NSUInteger)selected];
    NSString *hasMoreKey = hasMoreKeys[(NSUInteger)selected];
    NSString *loadingKey = loadingKeys[(NSUInteger)selected];
    NSArray *items = [data[itemKey] isKindOfClass:NSArray.class] ? data[itemKey] : @[];
    BOOL hasMore = [data[hasMoreKey] respondsToSelector:@selector(boolValue)] ? [data[hasMoreKey] boolValue] : (items.count > 0);
    BOOL loading = [data[loadingKey] respondsToSelector:@selector(boolValue)] ? [data[loadingKey] boolValue] : NO;

    if (selected == 2) {
        NSInteger oldLimit = SX249RepostLimit(self);
        if ((NSUInteger)oldLimit < items.count) {
            NSInteger nextLimit = MIN((NSInteger)items.count, oldLimit + 8);
            SX249SetRepostLimit(self, nextLimit);
            SX249AppendLocalReposts(self, items, oldLimit, nextLimit);

            if ((NSUInteger)nextLimit >= items.count && hasMore && !loading) {
                SX249SetRepostLimit(self, nextLimit + 8);
                [self sx238_loadMoreTimeline:nil];
            }
            return;
        }

        if (hasMore && !loading) {
            if (oldLimit <= (NSInteger)items.count) SX249SetRepostLimit(self, oldLimit + 8);
            [self sx238_loadMoreTimeline:nil];
        }
        return;
    }

    if (hasMore && !loading) [self sx238_loadMoreTimeline:nil];
}

- (void)sx249_installScrollTriggerIfNeeded {
    UIScrollView *scrollView = SX249ScrollView(self);
    if (!scrollView) return;
    UIGestureRecognizer *pan = scrollView.panGestureRecognizer;
    if (objc_getAssociatedObject(pan, &SX249InstalledPanKey)) return;
    [pan addTarget:self action:@selector(sx249_handleProfileScroll:)];
    objc_setAssociatedObject(pan, &SX249InstalledPanKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static void SX249ViewDidLoad(id selfObject, SEL _cmd) {
    if (SX249PreviousViewDidLoadIMP) SX249PreviousViewDidLoadIMP(selfObject, _cmd);
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    [profile sx249_installScrollTriggerIfNeeded];
}

@implementation NativeProfileViewController (NativeProfileSeamless249Install)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;

        Method limitMethod = class_getInstanceMethod(cls, NSSelectorFromString(@"sx237_repostDisplayLimit"));
        if (limitMethod) {
            class_replaceMethod(cls,
                                NSSelectorFromString(@"sx237_repostDisplayLimit"),
                                (IMP)SX249DisplayLimit,
                                method_getTypeEncoding(limitMethod));
        }

        Method footerMethod = class_getInstanceMethod(cls, NSSelectorFromString(@"sx238_moreButtonWithTitle:action:enabled:"));
        if (footerMethod) {
            class_replaceMethod(cls,
                                NSSelectorFromString(@"sx238_moreButtonWithTitle:action:enabled:"),
                                (IMP)SX249HiddenFooter,
                                method_getTypeEncoding(footerMethod));
        }

        Method viewDidLoadMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (viewDidLoadMethod) {
            IMP current = method_getImplementation(viewDidLoadMethod);
            if (current != (IMP)SX249ViewDidLoad) {
                SX249PreviousViewDidLoadIMP = (SX249ViewDidLoadIMP)current;
                class_replaceMethod(cls, @selector(viewDidLoad), (IMP)SX249ViewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
            }
        }
    });
}

@end
