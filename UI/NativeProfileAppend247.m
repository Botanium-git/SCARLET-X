#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

typedef void (*SX247ApplyProfileDataIMP)(id, SEL, NSDictionary *);
static SX247ApplyProfileDataIMP SX247PreviousApplyProfileDataIMP = NULL;

@interface NativeProfileViewController (NativeProfileAppend247Private)
- (UIView *)sx223_contentView;
- (UIStackView *)sx223_postsStackInContent:(UIView *)content;
- (NSInteger)sx237_repostDisplayLimit;
- (UIButton *)sx238_moreButtonWithTitle:(NSString *)title action:(SEL)action enabled:(BOOL)enabled;
- (UIView *)postViewForPost:(NSDictionary *)post;
@end

static NSString *SX247ItemID(id item) {
    if (![item isKindOfClass:NSDictionary.class]) return @"";
    id value = ((NSDictionary *)item)[@"id"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static BOOL SX247ArraysHaveSamePrefix(NSArray *oldItems, NSArray *newItems) {
    if (oldItems.count > newItems.count) return NO;
    for (NSUInteger idx = 0; idx < oldItems.count; idx++) {
        NSString *oldID = SX247ItemID(oldItems[idx]);
        NSString *newID = SX247ItemID(newItems[idx]);
        if (oldID.length == 0 || newID.length == 0 || ![oldID isEqualToString:newID]) return NO;
    }
    return YES;
}

static BOOL SX247OnlyPaginationKeysChanged(NSDictionary *oldData,
                                           NSDictionary *newData,
                                           NSString *itemsKey,
                                           NSString *cursorKey,
                                           NSString *hasMoreKey,
                                           NSString *loadingKey) {
    NSSet *allowed = [NSSet setWithArray:@[itemsKey, cursorKey, hasMoreKey, loadingKey]];
    NSMutableSet *allKeys = [NSMutableSet setWithArray:oldData.allKeys ?: @[]];
    [allKeys addObjectsFromArray:newData.allKeys ?: @[]];
    for (id key in allKeys) {
        id oldValue = oldData[key];
        id newValue = newData[key];
        BOOL same = (oldValue == newValue) || [oldValue isEqual:newValue];
        if (!same && ![allowed containsObject:key]) return NO;
    }
    return YES;
}

static void SX247RemoveTrailingFooter(UIStackView *stack) {
    while (stack.arrangedSubviews.count > 0) {
        UIView *last = stack.arrangedSubviews.lastObject;
        if (![last isKindOfClass:UIButton.class]) break;
        [stack removeArrangedSubview:last];
        [last removeFromSuperview];
    }
}

static NSUInteger SX247RenderLimit(NativeProfileViewController *profile, NSInteger selected, NSUInteger itemCount) {
    SEL stagedSEL = NSSelectorFromString(@"sx271_displayLimitForTab:");
    if ([profile respondsToSelector:stagedSEL]) {
        NSInteger (*msg)(id, SEL, NSInteger) = (NSInteger (*)(id, SEL, NSInteger))objc_msgSend;
        NSInteger limit = msg(profile, stagedSEL, selected);
        if (limit > 0) return MIN(itemCount, (NSUInteger)limit);
    }
    if (selected == 2) return MIN(itemCount, (NSUInteger)[profile sx237_repostDisplayLimit]);
    return itemCount;
}

static void SX247InstallFooter(NativeProfileViewController *profile,
                               UIStackView *stack,
                               NSInteger selected,
                               NSArray *items,
                               BOOL moreLoading,
                               BOOL hasMore) {
    NSUInteger renderCount = SX247RenderLimit(profile, selected, items.count);

    if (renderCount < items.count) {
        UIButton *button = [profile sx238_moreButtonWithTitle:@"さらに表示"
                                                       action:NSSelectorFromString(@"sx237_showMoreReposts:")
                                                      enabled:YES];
        [stack addArrangedSubview:button];
    } else if (hasMore) {
        NSString *title = moreLoading ? @"読み込み中…" : @"さらに読み込む";
        UIButton *button = [profile sx238_moreButtonWithTitle:title
                                                       action:NSSelectorFromString(@"sx238_loadMoreTimeline:")
                                                      enabled:!moreLoading];
        [stack addArrangedSubview:button];
    }
}

static BOOL SX247TryIncrementalPaginationUpdate(NativeProfileViewController *profile,
                                                NSDictionary *oldData,
                                                NSDictionary *newData) {
    if (!profile.isViewLoaded) return NO;

    NSInteger selected = 0;
    @try { selected = [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return NO; }
    if (selected < 0 || selected > 2) return NO;

    NSArray<NSString *> *itemKeys = @[@"posts", @"replies", @"reposts"];
    NSArray<NSString *> *cursorKeys = @[@"postsCursor", @"repliesCursor", @"repostsCursor"];
    NSArray<NSString *> *hasMoreKeys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    NSArray<NSString *> *loadingKeys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];

    NSString *itemKey = itemKeys[(NSUInteger)selected];
    NSString *cursorKey = cursorKeys[(NSUInteger)selected];
    NSString *hasMoreKey = hasMoreKeys[(NSUInteger)selected];
    NSString *loadingKey = loadingKeys[(NSUInteger)selected];

    NSArray *oldItems = [oldData[itemKey] isKindOfClass:NSArray.class] ? oldData[itemKey] : nil;
    NSArray *newItems = [newData[itemKey] isKindOfClass:NSArray.class] ? newData[itemKey] : nil;
    if (!oldItems || !newItems || oldItems.count == 0) return NO;
    if (!SX247ArraysHaveSamePrefix(oldItems, newItems)) return NO;
    if (!SX247OnlyPaginationKeysChanged(oldData, newData, itemKey, cursorKey, hasMoreKey, loadingKey)) return NO;

    BOOL oldMoreLoading = [oldData[loadingKey] respondsToSelector:@selector(boolValue)] ? [oldData[loadingKey] boolValue] : NO;
    BOOL newMoreLoading = [newData[loadingKey] respondsToSelector:@selector(boolValue)] ? [newData[loadingKey] boolValue] : NO;
    BOOL appended = newItems.count > oldItems.count;
    BOOL loadingChanged = oldMoreLoading != newMoreLoading;
    if (!appended && !loadingChanged) return NO;

    UIView *content = [profile sx223_contentView];
    UIStackView *stack = [profile sx223_postsStackInContent:content];
    if (![stack isKindOfClass:UIStackView.class]) return NO;

    profile.profileData = [newData copy];
    SX247RemoveTrailingFooter(stack);

    NSUInteger oldRendered = SX247RenderLimit(profile, selected, oldItems.count);
    NSUInteger newRendered = SX247RenderLimit(profile, selected, newItems.count);

    if (newRendered > oldRendered) {
        for (NSUInteger idx = oldRendered; idx < newRendered; idx++) {
            id item = newItems[idx];
            if (![item isKindOfClass:NSDictionary.class]) continue;
            [stack addArrangedSubview:[profile postViewForPost:(NSDictionary *)item]];
        }
    }

    BOOL hasMore = [newData[hasMoreKey] respondsToSelector:@selector(boolValue)] ? [newData[hasMoreKey] boolValue] : (newItems.count > 0);
    SX247InstallFooter(profile, stack, selected, newItems, newMoreLoading, hasMore);
    [content setNeedsLayout];
    return YES;
}

static void SX247ApplyProfileData(id selfObject, SEL _cmd, NSDictionary *profileData) {
    NativeProfileViewController *profile = (NativeProfileViewController *)selfObject;
    NSDictionary *oldData = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSDictionary *newData = [profileData isKindOfClass:NSDictionary.class] ? profileData : @{};

    if (SX247TryIncrementalPaginationUpdate(profile, oldData, newData)) return;
    if (SX247PreviousApplyProfileDataIMP) SX247PreviousApplyProfileDataIMP(selfObject, _cmd, profileData);
}

@implementation NativeProfileViewController (NativeProfileAppend247)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = self;
        SEL selector = @selector(applyProfileData:);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) return;
        IMP current = method_getImplementation(method);
        if (current == (IMP)SX247ApplyProfileData) return;
        SX247PreviousApplyProfileDataIMP = (SX247ApplyProfileDataIMP)current;
        class_replaceMethod(cls, selector, (IMP)SX247ApplyProfileData, method_getTypeEncoding(method));
    });
}

@end
