#import "NativeDrawerViewController.h"

@interface NativeDrawerViewController () <UITableViewDataSource, UITableViewDelegate>
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
        @{@"title":@"フォローする", @"icon":@"person.badge.plus"},
        @{@"title":@"プレミアム", @"icon":@"checkmark.seal", @"path":@"/i/premium_sign_up"},
        @{@"title":@"リスト", @"icon":@"list.bullet.rectangle", @"path":@"/i/lists"},
        @{@"title":@"コミュニティ", @"icon":@"person.3", @"path":@"/i/communities"},
        @{@"title":@"履歴", @"icon":@"bookmark"},
        @{@"title":@"クリエイタースタジオ", @"icon":@"paperplane"},
        @{@"title":@"ビジネス", @"icon":@"bolt"},
        @{@"title":@"広告", @"icon":@"arrow.up.right.square"},
        @{@"title":@"Scarlet X設定", @"icon":@"slider.horizontal.3", @"action":@"settings"},
        @{@"title":@"設定とプライバシー", @"icon":@"gearshape", @"path":@"/settings"},
        @{@"title":@"ログアウト", @"icon":@"rectangle.portrait.and.arrow.right"}
    ];

    self.dimmingView = [UIView new]; self.dimmingView.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; self.dimmingView.alpha=0; self.dimmingView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.dimmingView]; [self.dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)]];
    self.panelView=[UIView new]; self.panelView.backgroundColor=UIColor.systemBackgroundColor; self.panelView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.panelView];
    self.tableView=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.tableView.backgroundColor=UIColor.systemBackgroundColor; self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone; self.tableView.dataSource=self; self.tableView.delegate=self; self.tableView.rowHeight=54; self.tableView.translatesAutoresizingMaskIntoConstraints=NO; [self.panelView addSubview:self.tableView];
    self.tableView.tableHeaderView=[self buildProfileHeader];

    CGFloat width=MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86); self.panelLeadingConstraint=[self.panelView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-width];
    [NSLayoutConstraint activateConstraints:@[[self.dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],[self.dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],self.panelLeadingConstraint,[self.panelView.topAnchor constraintEqualToAnchor:self.view.topAnchor],[self.panelView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[self.panelView.widthAnchor constraintEqualToConstant:width],[self.tableView.topAnchor constraintEqualToAnchor:self.panelView.safeAreaLayoutGuide.topAnchor],[self.tableView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor],[self.tableView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor],[self.tableView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor]]];
    UISwipeGestureRecognizer *swipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedClosed:)]; swipe.direction=UISwipeGestureRecognizerDirectionLeft; [self.panelView addGestureRecognizer:swipe];
}

- (UIView *)buildProfileHeader {
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,340,142)];
    UIImageView *avatar=[[UIImageView alloc] initWithFrame:CGRectMake(16,12,44,44)]; avatar.layer.cornerRadius=22; avatar.clipsToBounds=YES; avatar.backgroundColor=UIColor.secondarySystemBackgroundColor; avatar.image=[UIImage systemImageNamed:@"person.crop.circle.fill"]; [header addSubview:avatar];
    NSString *avatarURL=[self.profileData[@"avatarURL"] isKindOfClass:NSString.class]?self.profileData[@"avatarURL"]:nil;
    if(avatarURL.length){ NSURL *u=[NSURL URLWithString:avatarURL]; if(u) NSURLSession.sharedSession ? [NSURLSession.sharedSession dataTaskWithURL:u completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){ if(!data)return; UIImage *img=[UIImage imageWithData:data]; if(!img)return; dispatch_async(dispatch_get_main_queue(),^{ avatar.image=img; }); }] .resume : (void)0; }
    UILabel *name=[[UILabel alloc] initWithFrame:CGRectMake(16,64,300,24)]; name.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold]; name.text=[self.profileData[@"name"] isKindOfClass:NSString.class]?self.profileData[@"name"]:@""; [header addSubview:name];
    UILabel *handle=[[UILabel alloc] initWithFrame:CGRectMake(16,87,300,20)]; handle.font=[UIFont systemFontOfSize:15]; handle.textColor=UIColor.secondaryLabelColor; handle.text=[self.profileData[@"handle"] isKindOfClass:NSString.class]?self.profileData[@"handle"]:@""; [header addSubview:handle];
    UILabel *counts=[[UILabel alloc] initWithFrame:CGRectMake(16,112,310,22)]; counts.font=[UIFont systemFontOfSize:14]; counts.textColor=UIColor.secondaryLabelColor; NSString *following=[self.profileData[@"following"] isKindOfClass:NSString.class]?self.profileData[@"following"]:@""; NSString *followers=[self.profileData[@"followers"] isKindOfClass:NSString.class]?self.profileData[@"followers"]:@""; counts.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",following,followers]; [header addSubview:counts];
    return header;
}

- (void)presentInParent:(UIViewController *)parent { [parent addChildViewController:self]; self.view.frame=parent.view.bounds; self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [parent.view addSubview:self.view]; [self didMoveToParentViewController:parent]; [self.view layoutIfNeeded]; self.panelLeadingConstraint.constant=0; [UIView animateWithDuration:.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{self.dimmingView.alpha=1;[self.view layoutIfNeeded];} completion:nil]; }
- (void)dismissAnimated:(BOOL)animated { CGFloat width=self.panelView.bounds.size.width?:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86); self.panelLeadingConstraint.constant=-width; void(^changes)(void)=^{self.dimmingView.alpha=0;[self.view layoutIfNeeded];}; void(^completion)(BOOL)=^(BOOL finished){[self willMoveToParentViewController:nil];[self.view removeFromSuperview];[self removeFromParentViewController];}; if(animated)[UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:changes completion:completion]; else{changes();completion(YES);} }
- (void)backgroundTapped:(id)sender{[self dismissAnimated:YES];} - (void)swipedClosed:(id)sender{[self dismissAnimated:YES];}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"drawer"]; if(!cell)cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"drawer"]; NSDictionary *item=self.items[indexPath.row]; cell.textLabel.text=item[@"title"]; cell.textLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; cell.imageView.image=[UIImage systemImageNamed:item[@"icon"]]; return cell; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { [tableView deselectRowAtIndexPath:indexPath animated:YES]; NSDictionary *item=self.items[indexPath.row]; id<NativeDrawerViewControllerDelegate> delegate=self.delegate; NSString *action=item[@"action"],*path=item[@"path"]; if(!action&&!path)return; [self dismissAnimated:YES]; if([action isEqual:@"settings"])[delegate nativeDrawerDidSelectScarletSettings:self]; else if(path)[delegate nativeDrawer:self didSelectPath:path]; }
@end
