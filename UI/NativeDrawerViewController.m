#import "NativeDrawerViewController.h"

@interface NativeDrawerViewController () <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIView *dimmingView;
@property(nonatomic,strong) UIView *panelView;
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,strong) NSLayoutConstraint *panelLeadingConstraint;
@end

@implementation NativeDrawerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[
        @{@"title":@"プロフィール", @"icon":@"person", @"path":@"/i/profile"},
        @{@"title":@"プレミアム", @"icon":@"checkmark.seal", @"path":@"/i/premium_sign_up"},
        @{@"title":@"ブックマーク", @"icon":@"bookmark", @"path":@"/i/bookmarks"},
        @{@"title":@"リスト", @"icon":@"list.bullet.rectangle", @"path":@"/i/lists"},
        @{@"title":@"コミュニティ", @"icon":@"person.3", @"path":@"/i/communities"},
        @{@"title":@"Scarlet X設定", @"icon":@"gearshape", @"action":@"settings"},
        @{@"title":@"設定とプライバシー", @"icon":@"gear", @"path":@"/settings"}
    ];

    self.dimmingView = [UIView new];
    self.dimmingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    self.dimmingView.alpha = 0;
    self.dimmingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dimmingView];
    [self.dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)]];

    self.panelView = [UIView new];
    self.panelView.backgroundColor = UIColor.systemBackgroundColor;
    self.panelView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.panelView];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 54;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panelView addSubview:self.tableView];

    CGFloat width = MIN(340.0, UIScreen.mainScreen.bounds.size.width * 0.86);
    self.panelLeadingConstraint = [self.panelView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-width];
    [NSLayoutConstraint activateConstraints:@[
        [self.dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        self.panelLeadingConstraint,
        [self.panelView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.panelView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.panelView.widthAnchor constraintEqualToConstant:width],
        [self.tableView.topAnchor constraintEqualToAnchor:self.panelView.safeAreaLayoutGuide.topAnchor constant:12],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor]
    ]];

    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedClosed:)];
    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.panelView addGestureRecognizer:swipe];
}

- (void)presentInParent:(UIViewController *)parent {
    [parent addChildViewController:self];
    self.view.frame = parent.view.bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [parent.view addSubview:self.view];
    [self didMoveToParentViewController:parent];
    [self.view layoutIfNeeded];
    self.panelLeadingConstraint.constant = 0;
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.dimmingView.alpha = 1;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)dismissAnimated:(BOOL)animated {
    CGFloat width = self.panelView.bounds.size.width ?: MIN(340.0, UIScreen.mainScreen.bounds.size.width * 0.86);
    self.panelLeadingConstraint.constant = -width;
    void (^changes)(void) = ^{ self.dimmingView.alpha = 0; [self.view layoutIfNeeded]; };
    void (^completion)(BOOL) = ^(BOOL finished){ [self willMoveToParentViewController:nil]; [self.view removeFromSuperview]; [self removeFromParentViewController]; };
    if (animated) [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:changes completion:completion];
    else { changes(); completion(YES); }
}

- (void)backgroundTapped:(id)sender { [self dismissAnimated:YES]; }
- (void)swipedClosed:(id)sender { [self dismissAnimated:YES]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = @"drawer";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    NSDictionary *item = self.items[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    cell.imageView.image = [UIImage systemImageNamed:item[@"icon"]];
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.items[indexPath.row];
    id<NativeDrawerViewControllerDelegate> delegate = self.delegate;
    [self dismissAnimated:YES];
    if ([item[@"action"] isEqual:@"settings"]) [delegate nativeDrawerDidSelectScarletSettings:self];
    else if (item[@"path"]) [delegate nativeDrawer:self didSelectPath:item[@"path"]];
}
@end
