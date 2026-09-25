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
        @{@"title":@"プレミアム", @"icon":@"checkmark.seal", @"path":@"/i/premium_sign_up"},
        @{@"title":@"履歴", @"icon":@"bookmark", @"path":@"/i/history"},
        @{@"title":@"コミュニティ", @"icon":@"person.3", @"path":@"/i/communities"},
        @{@"title":@"リスト", @"icon":@"list.bullet.rectangle", @"path":@"/i/lists"},
        @{@"title":@"スペース", @"icon":@"waveform.circle", @"path":@"/i/spaces/start"},
        @{@"title":@"フォローリクエスト", @"icon":@"person.badge.clock", @"path":@"/follower_requests"},
        @{@"title":@"クリエイタースタジオ", @"icon":@"paperplane", @"path":@"/i/monetization"},
        @{@"title":@"設定とプライバシー", @"icon":@"gearshape", @"path":@"/settings"},
        @{@"title":@"Scarlet X", @"icon":@"slider.horizontal.3", @"action":@"settings"}
    ];
    self.dimmingView=[UIView new]; self.dimmingView.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; self.dimmingView.alpha=0; self.dimmingView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.dimmingView]; [self.dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)]];
    self.panelView=[UIView new]; self.panelView.backgroundColor=UIColor.systemBackgroundColor; self.panelView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.panelView];
    self.tableView=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.tableView.backgroundColor=UIColor.systemBackgroundColor; self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone; self.tableView.dataSource=self; self.tableView.delegate=self; self.tableView.rowHeight=54; self.tableView.translatesAutoresizingMaskIntoConstraints=NO; [self.panelView addSubview:self.tableView];
    self.tableView.tableHeaderView=[self buildProfileHeader];
    CGFloat width=MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86); self.panelLeadingConstraint=[self.panelView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-width];
    [NSLayoutConstraint activateConstraints:@[[self.dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],[self.dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],self.panelLeadingConstraint,[self.panelView.topAnchor constraintEqualToAnchor:self.view.topAnchor],[self.panelView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[self.panelView.widthAnchor constraintEqualToConstant:width],[self.tableView.topAnchor constraintEqualToAnchor:self.panelView.safeAreaLayoutGuide.topAnchor],[self.tableView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor],[self.tableView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor],[self.tableView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor]]];
    UISwipeGestureRecognizer *swipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedClosed:)]; swipe.direction=UISwipeGestureRecognizerDirectionLeft; [self.panelView addGestureRecognizer:swipe];
}

- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView {
    if(![urlString isKindOfClass:NSString.class]||urlString.length==0)return;
    NSURL *url=[NSURL URLWithString:urlString]; if(!url)return;
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){ if(!data)return; UIImage *image=[UIImage imageWithData:data]; if(!image)return; dispatch_async(dispatch_get_main_queue(),^{ imageView.image=image; }); }] resume];
}

- (UIImageView *)accountAvatarAtX:(CGFloat)x y:(CGFloat)y size:(CGFloat)size URL:(NSString *)url {
    UIImageView *view=[[UIImageView alloc] initWithFrame:CGRectMake(x,y,size,size)];
    view.layer.cornerRadius=size/2.0; view.clipsToBounds=YES; view.contentMode=UIViewContentModeScaleAspectFill; view.backgroundColor=UIColor.secondarySystemBackgroundColor; view.image=[UIImage systemImageNamed:@"person.crop.circle.fill"];
    [self loadImageURLString:url into:view];
    return view;
}

- (UIView *)buildProfileHeader {
    NSArray *accounts=[self.profileData[@"accounts"] isKindOfClass:NSArray.class]?self.profileData[@"accounts"]:@[];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,340,184)];
    UIImageView *avatar=[self accountAvatarAtX:18 y:12 size:48 URL:self.profileData[@"avatarURL"]]; [header addSubview:avatar];

    CGFloat x=76;
    for(NSDictionary *account in accounts){
        if(x>276)break;
        if(![account isKindOfClass:NSDictionary.class])continue;
        NSString *handle=[account[@"handle"] isKindOfClass:NSString.class]?account[@"handle"]:@"";
        NSString *avatarURL=[account[@"avatarURL"] isKindOfClass:NSString.class]?account[@"avatarURL"]:@"";
        UIImageView *other=[self accountAvatarAtX:x y:12 size:36 URL:avatarURL]; [header addSubview:other];
        UILabel *accountHandle=[[UILabel alloc] initWithFrame:CGRectMake(x-10,51,56,30)];
        accountHandle.font=[UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        accountHandle.textColor=UIColor.secondaryLabelColor;
        accountHandle.textAlignment=NSTextAlignmentCenter;
        accountHandle.numberOfLines=2;
        accountHandle.adjustsFontSizeToFitWidth=YES;
        accountHandle.minimumScaleFactor=.7;
        accountHandle.text=handle;
        [header addSubview:accountHandle];
        x+=66;
    }

    UILabel *name=[[UILabel alloc] initWithFrame:CGRectMake(18,82,304,24)]; name.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold]; name.text=[self.profileData[@"name"] isKindOfClass:NSString.class]?self.profileData[@"name"]:@""; [header addSubview:name];
    UILabel *handle=[[UILabel alloc] initWithFrame:CGRectMake(18,106,304,21)]; handle.font=[UIFont systemFontOfSize:15]; handle.textColor=UIColor.secondaryLabelColor; handle.text=[self.profileData[@"handle"] isKindOfClass:NSString.class]?self.profileData[@"handle"]:@""; [header addSubview:handle];
    UILabel *counts=[[UILabel alloc] initWithFrame:CGRectMake(18,134,310,22)]; counts.font=[UIFont systemFontOfSize:14]; counts.textColor=UIColor.secondaryLabelColor;
    NSString *following=[self.profileData[@"following"] isKindOfClass:NSString.class]?self.profileData[@"following"]:@"";
    NSString *followers=[self.profileData[@"followers"] isKindOfClass:NSString.class]?self.profileData[@"followers"]:@"";
    NSDictionary *followerProbe=[self.profileData[@"followerProbe"] isKindOfClass:NSDictionary.class]?self.profileData[@"followerProbe"]:nil;
    NSDictionary *probeCounts=[followerProbe[@"counts"] isKindOfClass:NSDictionary.class]?followerProbe[@"counts"]:nil;
    NSNumber *friendsCount=[probeCounts[@"friends_count"] isKindOfClass:NSNumber.class]?probeCounts[@"friends_count"]:nil;
    NSNumber *followersCount=[probeCounts[@"followers_count"] isKindOfClass:NSNumber.class]?probeCounts[@"followers_count"]:nil;
    if(following.length==0&&friendsCount)following=friendsCount.stringValue;
    if(followers.length==0&&followersCount)followers=followersCount.stringValue;
    counts.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",following,followers]; [header addSubview:counts];
    if(accounts.count){ UILabel *hint=[[UILabel alloc] initWithFrame:CGRectMake(18,160,304,18)]; hint.font=[UIFont systemFontOfSize:12]; hint.textColor=UIColor.tertiaryLabelColor; hint.text=@"ログイン中の他のアカウント"; [header addSubview:hint]; }
    return header;
}

- (void)presentInParent:(UIViewController *)parent { [parent addChildViewController:self]; self.view.frame=parent.view.bounds; self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [parent.view addSubview:self.view]; [self didMoveToParentViewController:parent]; [self.view layoutIfNeeded]; self.panelLeadingConstraint.constant=0; [UIView animateWithDuration:.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{self.dimmingView.alpha=1;[self.view layoutIfNeeded];} completion:nil]; }
- (void)dismissAnimated:(BOOL)animated { CGFloat width=self.panelView.bounds.size.width?:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86); self.panelLeadingConstraint.constant=-width; void(^changes)(void)=^{self.dimmingView.alpha=0;[self.view layoutIfNeeded];}; void(^completion)(BOOL)=^(BOOL finished){[self willMoveToParentViewController:nil];[self.view removeFromSuperview];[self removeFromParentViewController];}; if(animated)[UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:changes completion:completion]; else{changes();completion(YES);} }
- (void)backgroundTapped:(id)sender{[self dismissAnimated:YES];}
- (void)swipedClosed:(id)sender{[self dismissAnimated:YES];}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"drawer"]; if(!cell)cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"drawer"]; NSDictionary *item=self.items[indexPath.row]; cell.textLabel.text=item[@"title"]; cell.textLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; cell.imageView.image=[UIImage systemImageNamed:item[@"icon"]]; return cell; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { [tableView deselectRowAtIndexPath:indexPath animated:YES]; NSDictionary *item=self.items[indexPath.row]; id<NativeDrawerViewControllerDelegate> delegate=self.delegate; NSString *action=item[@"action"],*path=item[@"path"]; if(!action&&!path)return; [self dismissAnimated:YES]; if([action isEqual:@"settings"])[delegate nativeDrawerDidSelectScarletSettings:self]; else if(path)[delegate nativeDrawer:self didSelectPath:path]; }
@end
