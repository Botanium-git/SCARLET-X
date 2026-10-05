#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX251AdapterKey;
static char SX251TableKey;

typedef void (*SX251SetProfileDataIMP)(id, SEL, NSDictionary *);
static SX251SetProfileDataIMP SX251PreviousSetProfileDataIMP = NULL;

typedef void (*SX251ViewDidLoadIMP)(id, SEL);
static SX251ViewDidLoadIMP SX251PreviousViewDidLoadIMP = NULL;

typedef void (*SX251ViewDidLayoutIMP)(id, SEL);
static SX251ViewDidLayoutIMP SX251PreviousViewDidLayoutIMP = NULL;

@interface NativeProfileViewController (NativeProfileTable251Private)
- (UIView *)postViewForPost:(NSDictionary *)post;
- (void)profileTabSwiped:(UISwipeGestureRecognizer *)gesture;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

@interface SX251TimelineAdapter : NSObject <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, weak) NativeProfileViewController *profile;
@property(nonatomic, weak) UITableView *tableView;
@end

@implementation SX251TimelineAdapter

- (NSInteger)selectedTab {
    @try { return [[self.profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *exception) { return -1; }
}

- (NSDictionary *)data {
    return [self.profile.profileData isKindOfClass:NSDictionary.class] ? self.profile.profileData : @{};
}

- (NSArray *)itemsForTab:(NSInteger)tab data:(NSDictionary *)data {
    if (tab < 0 || tab > 2) return @[];
    NSArray<NSString *> *keys = @[@"posts", @"replies", @"reposts"];
    id value = data[keys[(NSUInteger)tab]];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (BOOL)isInitialLoadingForTab:(NSInteger)tab data:(NSDictionary *)data {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsLoading", @"repliesLoading", @"repostsLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (BOOL)isMoreLoadingForTab:(NSInteger)tab data:(NSDictionary *)data {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (BOOL)hasMoreForTab:(NSInteger)tab data:(NSDictionary *)data items:(NSArray *)items {
    if (tab < 0 || tab > 2) return NO;
    NSArray<NSString *> *keys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore"];
    id value = data[keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (items.count > 0);
}

- (NSString *)emptyTextForTab:(NSInteger)tab loading:(BOOL)loading {
    if (tab == 3) return @"メディアはまだ接続していません";
    if (tab == 0) return loading ? @"Xからポストを読み込み中…" : @"通常ポストはありません";
    if (tab == 1) return loading ? @"Xから返信を読み込み中…" : @"返信はありません";
    if (tab == 2) return loading ? @"Xからリポストを読み込み中…" : @"リポストはありません";
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger tab = [self selectedTab];
    if (tab == 3) return 1;
    NSDictionary *data = [self data];
    NSArray *items = [self itemsForTab:tab data:data];
    if (items.count == 0) return 1;
    BOOL hasMore = [self hasMoreForTab:tab data:data items:items];
    return (NSInteger)items.count + (hasMore ? 1 : 0);
}

- (UITableViewCell *)stateCellForTable:(UITableView *)tableView text:(NSString *)text {
    static NSString *identifier = @"SX251StateCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;
    cell.textLabel.text = text ?: @"";
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = UIColor.secondaryLabelColor;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.numberOfLines = 0;
    return cell;
}

- (UITableViewCell *)postCellForTable:(UITableView *)tableView post:(NSDictionary *)post {
    static NSString *identifier = @"SX251PostCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;

    for (UIView *subview in [cell.contentView.subviews copy]) [subview removeFromSuperview];

    UIView *postView = [self.profile postViewForPost:post];
    postView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:postView];
    [NSLayoutConstraint activateConstraints:@[
        [postView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [postView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [postView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [postView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tab = [self selectedTab];
    NSDictionary *data = [self data];
    if (tab == 3) return [self stateCellForTable:tableView text:[self emptyTextForTab:tab loading:NO]];

    NSArray *items = [self itemsForTab:tab data:data];
    if (items.count == 0) {
        BOOL loading = [self isInitialLoadingForTab:tab data:data];
        return [self stateCellForTable:tableView text:[self emptyTextForTab:tab loading:loading]];
    }

    if ((NSUInteger)indexPath.row < items.count) {
        id item = items[(NSUInteger)indexPath.row];
        if ([item isKindOfClass:NSDictionary.class]) return [self postCellForTable:tableView post:item];
        return [self stateCellForTable:tableView text:@""];
    }

    BOOL loading = [self isMoreLoadingForTab:tab data:data];
    return [self stateCellForTable:tableView text:(loading ? @"読み込み中…" : @"さらに読み込む")];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 240.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tab = [self selectedTab];
    NSDictionary *data = [self data];
    NSArray *items = [self itemsForTab:tab data:data];
    if (tab == 3 || items.count == 0 || (NSUInteger)indexPath.row >= items.count) return 64.0;
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tab = [self selectedTab];
    if (tab < 0 || tab > 2) return;
    NSDictionary *data = [self data];
    NSArray *items = [self itemsForTab:tab data:data];
    if ((NSUInteger)indexPath.row != items.count) return;
    if (![self hasMoreForTab:tab data:data items:items]) return;
    if ([self isMoreLoadingForTab:tab data:data]) return;
    [self.profile sx238_loadMoreTimeline:nil];
}

@end

static UIStackView *SX251FindPostsStack(UIView *content) {
    if (![content isKindOfClass:UIView.class]) return nil;
    for (UIView *view in content.subviews) {
        if (![view isKindOfClass:UIStackView.class]) continue;
        UIStackView *stack = (UIStackView *)view;
        if (stack.axis == UILayoutConstraintAxisVertical) return stack;
    }
    return nil;
}

static CGFloat SX251HeaderHeight(UIView *header, CGFloat width) {
    if (![header isKindOfClass:UIView.class]) return 0;
    CGRect frame = header.frame;
    frame.size.width = MAX(1.0, width);
    frame.size.height = MAX(frame.size.height, 1.0);
    header.frame = frame;
    [header setNeedsLayout];
    [header layoutIfNeeded];

    CGFloat maxY = 0;
    for (UIView *view in header.subviews) {
        if (view.hidden) continue;
        maxY = MAX(maxY, CGRectGetMaxY(view.frame));
    }
    return ceil(MAX(1.0, maxY));
}

static void SX251ResizeHeaderIfNeeded(NativeProfileViewController *profile) {
    UITableView *table = objc_getAssociatedObject(profile, &SX251TableKey);
    UIView *header = table.tableHeaderView;
    if (![table isKindOfClass:UITableView.class] || ![header isKindOfClass:UIView.class]) return;
    CGFloat width = CGRectGetWidth(table.bounds);
    if (width <= 0) return;
    CGFloat height = SX251HeaderHeight(header, width);
    if (fabs(CGRectGetWidth(header.frame) - width) < 0.5 && fabs(CGRectGetHeight(header.frame) - height) < 0.5) return;
    CGRect frame = header.frame;
    frame.size.width = width;
    frame.size.height = height;
    header.frame = frame;
    table.tableHeaderView = header;
}

static void SX251ReloadVisibleTimeline(NativeProfileViewController *profile) {
    UITableView *table = objc_getAssociatedObject(profile, &SX251TableKey);
    SX251TimelineAdapter *adapter = objc_getAssociatedObject(profile, &SX251AdapterKey);
    if (![table isKindOfClass:UITableView.class] || !adapter) return;
    [table reloadData];
    SX251ResizeHeaderIfNeeded(profile);
}

static void SX251InstallTable(NativeProfileViewController *profile) {
    if (!profile.isViewLoaded || objc_getAssociatedObject(profile, &SX251TableKey)) return;

    UIScrollView *oldScroll = nil;
    UIView *content = nil;
    @try {
        oldScroll = [profile valueForKey:@"scrollView"];
        content = [profile valueForKey:@"contentView"];
    } @catch (__unused NSException *exception) {}
    if (![oldScroll isKindOfClass:UIScrollView.class] || ![content isKindOfClass:UIView.class]) return;

    [profile.view layoutIfNeeded];

    UIStackView *postsStack = SX251FindPostsStack(content);
    if (postsStack) {
        NSMutableArray<NSLayoutConstraint *> *remove = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in [content.constraints copy]) {
            if (constraint.firstItem == postsStack || constraint.secondItem == postsStack) [remove addObject:constraint];
        }
        [NSLayoutConstraint deactivateConstraints:remove];
        [postsStack removeFromSuperview];
    }

    CGFloat width = CGRectGetWidth(profile.view.bounds);
    CGFloat headerHeight = SX251HeaderHeight(content, width);

    [content removeFromSuperview];
    content.translatesAutoresizingMaskIntoConstraints = YES;
    content.frame = CGRectMake(0, 0, width, headerHeight);
    [oldScroll removeFromSuperview];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.backgroundColor = UIColor.systemBackgroundColor;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 240.0;
    table.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    SX251TimelineAdapter *adapter = [SX251TimelineAdapter new];
    adapter.profile = profile;
    adapter.tableView = table;
    table.dataSource = adapter;
    table.delegate = adapter;
    table.tableHeaderView = content;

    [profile.view insertSubview:table atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [table.topAnchor constraintEqualToAnchor:profile.view.topAnchor],
        [table.leadingAnchor constraintEqualToAnchor:profile.view.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:profile.view.trailingAnchor],
        [table.bottomAnchor constraintEqualToAnchor:profile.view.bottomAnchor]
    ]];

    UISwipeGestureRecognizer *left = [[UISwipeGestureRecognizer alloc] initWithTarget:profile action:@selector(profileTabSwiped:)];
    left.direction = UISwipeGestureRecognizerDirectionLeft;
    [table addGestureRecognizer:left];
    UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc] initWithTarget:profile action:@selector(profileTabSwiped:)];
    right.direction = UISwipeGestureRecognizerDirectionRight;
    [table addGestureRecognizer:right];

    objc_setAssociatedObject(profile, &SX251TableKey, table, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(profile, &SX251AdapterKey, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try { [profile setValue:table forKey:@"scrollView"]; } @catch (__unused NSException *exception) {}

    [table reloadData];
    SX251ResizeHeaderIfNeeded(profile);
}

static void SX251ViewDidLoad(id selfObject, SEL _cmd) {
    if (SX251PreviousViewDidLoadIMP) SX251PreviousViewDidLoadIMP(selfObject, _cmd);
    SX251InstallTable((NativeProfileViewController *)selfObject);
}

static void SX251ViewDidLayout(id selfObject, SEL _cmd) {
    if (SX251PreviousViewDidLayoutIMP) SX251PreviousViewDidLayoutIMP(selfObject, _cmd);
    SX251ResizeHeaderIfNeeded((NativeProfileViewController *)selfObject);
}

static void SX251SetProfileData(id selfObject, SEL _cmd, NSDictionary *profileData) {
    if (SX251PreviousSetProfileDataIMP) SX251PreviousSetProfileDataIMP(selfObject, _cmd, profileData);
    __weak NativeProfileViewController *weakProfile = (NativeProfileViewController *)selfObject;
    dispatch_async(dispatch_get_main_queue(), ^{
        NativeProfileViewController *profile = weakProfile;
        if (!profile) return;
        SX251ReloadVisibleTimeline(profile);
    });
}

@implementation NativeProfileViewController (NativeProfileTable251)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = self;

        Method viewDidLoadMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (viewDidLoadMethod) {
            SX251PreviousViewDidLoadIMP = (SX251ViewDidLoadIMP)method_getImplementation(viewDidLoadMethod);
            class_replaceMethod(cls, @selector(viewDidLoad), (IMP)SX251ViewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
        }

        Method layoutMethod = class_getInstanceMethod(cls, @selector(viewDidLayoutSubviews));
        if (layoutMethod) {
            SX251PreviousViewDidLayoutIMP = (SX251ViewDidLayoutIMP)method_getImplementation(layoutMethod);
            class_replaceMethod(cls, @selector(viewDidLayoutSubviews), (IMP)SX251ViewDidLayout, method_getTypeEncoding(layoutMethod));
        }

        SEL setter = NSSelectorFromString(@"setProfileData:");
        Method setterMethod = class_getInstanceMethod(cls, setter);
        if (setterMethod) {
            SX251PreviousSetProfileDataIMP = (SX251SetProfileDataIMP)method_getImplementation(setterMethod);
            class_replaceMethod(cls, setter, (IMP)SX251SetProfileData, method_getTypeEncoding(setterMethod));
        }
    });
}

@end
