#import "NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX252StateKey;

typedef NSInteger (*SX252RowsIMP)(id, SEL, UITableView *, NSInteger);
static SX252RowsIMP SX252PreviousRowsIMP = NULL;

typedef void (*SX252ScrollIMP)(id, SEL, UIScrollView *);
static SX252ScrollIMP SX252PreviousScrollIMP = NULL;

@interface NativeProfileViewController (NativeProfileSingleFlight252Private)
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NativeProfileViewController *SX252Profile(id adapter) {
    id value = nil;
    @try { value = [adapter valueForKey:@"profile"]; }
    @catch (__unused NSException *exception) {}
    return [value isKindOfClass:NativeProfileViewController.class] ? value : nil;
}

static NSInteger SX252SelectedTab(NativeProfileViewController *profile) {
    if (!profile) return -1;
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

static NSMutableDictionary *SX252StateForTab(id adapter, NSInteger tab, BOOL create) {
    if (!adapter || tab < 0 || tab > 2) return nil;
    NSMutableDictionary *all = objc_getAssociatedObject(adapter, &SX252StateKey);
    if (!all && create) {
        all = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(adapter, &SX252StateKey, all, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSString *key = [NSString stringWithFormat:@"%ld", (long)tab];
    NSMutableDictionary *state = [all[key] isKindOfClass:NSMutableDictionary.class] ? all[key] : nil;
    if (!state && create) {
        state = [@{ @"inFlight": @NO, @"pending": @NO, @"generation": @0 } mutableCopy];
        all[key] = state;
    }
    return state;
}

static NSArray *SX252Items(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return @[];
    NSArray<NSString *> *keys = @[@"posts", @"replies", @"reposts"];
    id value = data[keys[(NSUInteger)tab]];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static BOOL SX252MoreLoading(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static BOOL SX252HasMore(NSDictionary *data, NSInteger tab, NSArray *items) {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (items.count > 0);
}

static BOOL SX252NearBottom(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:UIScrollView.class]) return NO;
    CGFloat visibleBottom = scrollView.contentOffset.y + CGRectGetHeight(scrollView.bounds);
    CGFloat distance = scrollView.contentSize.height - visibleBottom;
    CGFloat threshold = MAX(1400.0, CGRectGetHeight(scrollView.bounds) * 2.0);
    return distance <= threshold;
}

static void SX252Request(id adapter, UITableView *tableView, BOOL allowPending);
static void SX252Evaluate(id adapter, UITableView *tableView, BOOL allowPending);

static void SX252StartWatchdog(id adapter, UITableView *tableView, NSInteger tab, NSInteger generation) {
    __weak id weakAdapter = adapter;
    __weak UITableView *weakTable = tableView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(22.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id strongAdapter = weakAdapter;
        UITableView *strongTable = weakTable;
        if (!strongAdapter || !strongTable) return;
        NSMutableDictionary *state = SX252StateForTab(strongAdapter, tab, NO);
        if (!state) return;
        if ([state[@"generation"] integerValue] != generation) return;
        if (![state[@"inFlight"] boolValue]) return;

        NativeProfileViewController *profile = SX252Profile(strongAdapter);
        NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
        if (SX252MoreLoading(data, tab)) return;

        state[@"inFlight"] = @NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            SX252Evaluate(strongAdapter, strongTable, NO);
        });
    });
}

static void SX252Request(id adapter, UITableView *tableView, BOOL allowPending) {
    NativeProfileViewController *profile = SX252Profile(adapter);
    NSInteger tab = SX252SelectedTab(profile);
    if (!profile || tab < 0 || tab > 2 || ![tableView isKindOfClass:UITableView.class]) return;

    NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSArray *items = SX252Items(data, tab);
    if (items.count == 0 || !SX252HasMore(data, tab, items)) return;

    NSMutableDictionary *state = SX252StateForTab(adapter, tab, YES);
    BOOL loading = SX252MoreLoading(data, tab);
    BOOL inFlight = [state[@"inFlight"] boolValue];

    if (loading || inFlight) {
        if (allowPending) state[@"pending"] = @YES;
        return;
    }

    state[@"inFlight"] = @YES;
    state[@"pending"] = @NO;
    NSInteger generation = [state[@"generation"] integerValue] + 1;
    state[@"generation"] = @(generation);

    [[DiagnosticsStore shared] addEvent:@"Native profile single-flight started"
                                 detail:[NSString stringWithFormat:@"tab=%ld items=%lu", (long)tab, (unsigned long)items.count]
                                    url:nil];

    SEL selector = NSSelectorFromString(@"sx238_loadMoreTimeline:");
    if ([profile respondsToSelector:selector]) {
        ((void(*)(id, SEL, id))objc_msgSend)(profile, selector, nil);
        SX252StartWatchdog(adapter, tableView, tab, generation);
    } else {
        state[@"inFlight"] = @NO;
    }
}

static void SX252Evaluate(id adapter, UITableView *tableView, BOOL allowPending) {
    if (!SX252NearBottom(tableView)) return;
    SX252Request(adapter, tableView, allowPending);
}

static NSInteger SX252Rows(id selfObject, SEL _cmd, UITableView *tableView, NSInteger section) {
    NSInteger rows = SX252PreviousRowsIMP ? SX252PreviousRowsIMP(selfObject, _cmd, tableView, section) : 0;

    if (@available(iOS 10.0, *)) {
        if (tableView.prefetchDataSource != (id<UITableViewDataSourcePrefetching>)selfObject) {
            tableView.prefetchDataSource = (id<UITableViewDataSourcePrefetching>)selfObject;
        }
    }

    NativeProfileViewController *profile = SX252Profile(selfObject);
    NSInteger tab = SX252SelectedTab(profile);
    if (profile && tab >= 0 && tab <= 2) {
        NSMutableDictionary *state = SX252StateForTab(selfObject, tab, YES);
        NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
        BOOL loading = SX252MoreLoading(data, tab);
        BOOL inFlight = [state[@"inFlight"] boolValue];

        if (inFlight && !loading) {
            BOOL pending = [state[@"pending"] boolValue];
            state[@"inFlight"] = @NO;
            state[@"pending"] = @NO;

            [[DiagnosticsStore shared] addEvent:@"Native profile single-flight completed"
                                         detail:[NSString stringWithFormat:@"tab=%ld pending=%@", (long)tab, pending ? @"YES" : @"NO"]
                                            url:nil];

            __weak id weakAdapter = selfObject;
            __weak UITableView *weakTable = tableView;
            dispatch_async(dispatch_get_main_queue(), ^{
                id strongAdapter = weakAdapter;
                UITableView *strongTable = weakTable;
                if (!strongAdapter || !strongTable) return;
                if (pending || SX252NearBottom(strongTable)) {
                    SX252Request(strongAdapter, strongTable, NO);
                }
            });
        }
    }
    return rows;
}

static void SX252Scroll(id selfObject, SEL _cmd, UIScrollView *scrollView) {
    if (SX252PreviousScrollIMP) SX252PreviousScrollIMP(selfObject, _cmd, scrollView);
    if (![scrollView isKindOfClass:UITableView.class]) return;
    SX252Evaluate(selfObject, (UITableView *)scrollView, YES);
}

static void SX252Prefetch(id selfObject, SEL _cmd, UITableView *tableView, NSArray<NSIndexPath *> *indexPaths) {
    NativeProfileViewController *profile = SX252Profile(selfObject);
    NSInteger tab = SX252SelectedTab(profile);
    if (!profile || tab < 0 || tab > 2 || ![tableView isKindOfClass:UITableView.class]) return;

    NSDictionary *data = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSArray *items = SX252Items(data, tab);
    if (items.count == 0 || !SX252HasMore(data, tab, items)) return;

    NSInteger triggerRow = MAX(0, (NSInteger)items.count - 8);
    BOOL shouldPrefetch = NO;
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section == 0 && indexPath.row >= triggerRow) {
            shouldPrefetch = YES;
            break;
        }
    }
    if (!shouldPrefetch) return;

    [[DiagnosticsStore shared] addEvent:@"Native profile prefetch trigger"
                                 detail:[NSString stringWithFormat:@"tab=%ld triggerRow=%ld items=%lu", (long)tab, (long)triggerRow, (unsigned long)items.count]
                                    url:nil];
    SX252Request(selfObject, tableView, YES);
}

@interface SX252SingleFlightInstaller : NSObject
@end

@implementation SX252SingleFlightInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL rowsSelector = @selector(tableView:numberOfRowsInSection:);
        Method rowsMethod = class_getInstanceMethod(adapterClass, rowsSelector);
        if (rowsMethod) {
            IMP current = method_getImplementation(rowsMethod);
            if (current != (IMP)SX252Rows) {
                SX252PreviousRowsIMP = (SX252RowsIMP)current;
                class_replaceMethod(adapterClass, rowsSelector, (IMP)SX252Rows, method_getTypeEncoding(rowsMethod));
            }
        }

        SEL scrollSelector = @selector(scrollViewDidScroll:);
        Method scrollMethod = class_getInstanceMethod(adapterClass, scrollSelector);
        if (scrollMethod) {
            IMP current = method_getImplementation(scrollMethod);
            if (current != (IMP)SX252Scroll) {
                SX252PreviousScrollIMP = (SX252ScrollIMP)current;
                class_replaceMethod(adapterClass, scrollSelector, (IMP)SX252Scroll, method_getTypeEncoding(scrollMethod));
            }
        } else {
            class_addMethod(adapterClass, scrollSelector, (IMP)SX252Scroll, "v@:@");
        }

        SEL prefetchSelector = @selector(tableView:prefetchRowsAtIndexPaths:);
        if (!class_getInstanceMethod(adapterClass, prefetchSelector)) {
            class_addMethod(adapterClass, prefetchSelector, (IMP)SX252Prefetch, "v@:@@");
        }
    });
}

@end
