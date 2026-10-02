#import "NativeDrawerViewController.h"

@interface NativeDrawerViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,strong) UIView *dimmingView;
@property(nonatomic,strong) UIView *panelView;
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@property(nonatomic,strong) NSLayoutConstraint *panelLeadingConstraint;
@property(nonatomic,assign) BOOL accountSelectionInFlight;
@end

@implementation NativeDrawerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[
        @{@"title":@"プロフィール", @"icon":@"person", @"action":@"profile"},
        @{@"title":@"プレミアム", @"icon":@"checkmark.seal", @"path":@"/i/premium_sign_up"},
        @{@"title":@"履歴", @"icon":@"bookmark", @"path":@"/i/bookmarks"},
        @{@"title":@"コミュニティ", @"icon":@"person.3", @"path":@"/i/communities"},
        @{@"title":@"リスト", @"icon":@"list.bullet.rectangle", @"path":@"/lists"},
        @{@"title":@"スペース", @"icon":@"waveform.circle", @"path":@"/i/spaces/start"},
        @{@"title":@"フォローリクエスト", @"icon":@"person.badge.clock", @"path":@"/follower_requests"},
        @{@"title":@"クリエイタースタジオ", @"icon":@"paperplane", @"path":@"/i/jf/creators/studio"},
        @{@"title":@"設定とプライバシー", @"icon":@"gearshape", @"path":@"/settings/account"},
        @{@"title":@"Scarlet X", @"icon":@"slider.horizontal.3", @"action":@"settings"},
        @{@"title":@"ログアウト", @"icon":@"rectangle.portrait.and.arrow.right", @"path":@"/logout", @"destructive":@YES}
    ];
    self.dimmingView=[UIView new]; self.dimmingView.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; self.dimmingView.alpha=0; self.dimmingView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.dimmingView]; [self.dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)]];
    self.panelView=[UIView new]; self.panelView.backgroundColor=UIColor.systemBackgroundColor; self.panelView.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.panelView];
    self.tableView=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.tableView.backgroundColor=UIColor.systemBackgroundColor; self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone; self.tableView.dataSource=self; self.tableView.delegate=self; self.tableView.rowHeight=50; self.tableView.contentInset=UIEdgeInsetsMake(2,0,12,0); self.tableView.translatesAutoresizingMaskIntoConstraints=NO; [self.panelView addSubview:self.tableView];
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

- (void)accountProbeTapped:(UIButton *)sender {
    if(self.accountSelectionInFlight)return;
    NSArray *accounts=[self.profileData[@"accounts"] isKindOfClass:NSArray.class]?self.profileData[@"accounts"]:@[];
    NSInteger index=sender.tag;
    if(index<0||index>=accounts.count)return;
    NSDictionary *account=[accounts[index] isKindOfClass:NSDictionary.class]?accounts[index]:nil;
    if(!account)return;
    NSString *handle=[account[@"handle"] isKindOfClass:NSString.class]?account[@"handle"]:@"";
    NSString *screenName=[handle hasPrefix:@"@"]?[handle substringFromIndex:1]:handle;
    NSString *avatarURL=[account[@"avatarURL"] isKindOfClass:NSString.class]?account[@"avatarURL"]:@"";
    if(screenName.length==0)return;

    self.accountSelectionInFlight=YES;
    self.view.userInteractionEnabled=NO;

    NSURLComponents *components=[NSURLComponents componentsWithString:@"https://x.com/__scarletx_account_probe"];
    components.queryItems=@[[NSURLQueryItem queryItemWithName:@"screen_name" value:screenName],[NSURLQueryItem queryItemWithName:@"avatar" value:avatarURL]];
    NSString *path=components.URL.path ?: @"/__scarletx_account_probe";
    if(components.URL.query.length)path=[path stringByAppendingFormat:@"?%@",components.URL.query];
    id<NativeDrawerViewControllerDelegate> delegate=self.delegate;
    [self dismissAnimated:YES];
    [delegate nativeDrawer:self didSelectPath:path];
}

- (void)addAccountTapped:(UIButton *)sender {
    if(self.accountSelectionInFlight)return;
    self.accountSelectionInFlight=YES;
    self.view.userInteractionEnabled=NO;
    id<NativeDrawerViewControllerDelegate> delegate=self.delegate;
    [self dismissAnimated:YES];
    [delegate nativeDrawer:self didSelectPath:@"/i/flow/login"];
}

- (UIView *)buildProfileHeader {
    NSArray *accounts=[self.profileData[@"accounts"] isKindOfClass:NSArray.class]?self.profileData[@"accounts"]:@[];
    CGFloat headerWidth=MIN(320.0,UIScreen.mainScreen.bounds.size.width*.82);
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,headerWidth,150)];
    UIImageView *avatar=[self accountAvatarAtX:18 y:12 size:48 URL:self.profileData[@"avatarURL"]]; [header addSubview:avatar];

    UIButton *addAccount=[UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat addX=MAX(18.0,headerWidth-54.0);
    addAccount.frame=CGRectMake(addX,16,34,34);
    addAccount.layer.cornerRadius=17;
    addAccount.layer.borderWidth=1.5;
    addAccount.layer.borderColor=UIColor.secondaryLabelColor.CGColor;
    addAccount.tintColor=UIColor.labelColor;
    UIImageSymbolConfiguration *plusConfig=[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    [addAccount setImage:[UIImage systemImageNamed:@"plus" withConfiguration:plusConfig] forState:UIControlStateNormal];
    addAccount.accessibilityLabel=@"アカウントを追加";
    [addAccount addTarget:self action:@selector(addAccountTapped:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:addAccount];

    CGFloat x=addX-42.0;
    NSInteger accountIndex=0;
    NSInteger shown=0;
    for(NSDictionary *account in accounts){
        if(shown>=4)break;
        if(![account isKindOfClass:NSDictionary.class]){accountIndex++;continue;}
        NSString *handle=[account[@"handle"] isKindOfClass:NSString.class]?account[@"handle"]:@"";
        NSString *avatarURL=[account[@"avatarURL"] isKindOfClass:NSString.class]?account[@"avatarURL"]:@"";
        if(x<74.0)break;
        UIImageView *other=[self accountAvatarAtX:x y:16 size:34 URL:avatarURL]; [header addSubview:other];
        UIButton *probe=[UIButton buttonWithType:UIButtonTypeCustom];
        probe.frame=CGRectMake(x-5,11,44,44);
        probe.tag=accountIndex;
        probe.accessibilityLabel=[NSString stringWithFormat:@"%@ に切り替える",handle];
        [probe addTarget:self action:@selector(accountProbeTapped:) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:probe];
        x-=42;
        shown++;
        accountIndex++;
    }

    CGFloat textWidth=MAX(0.0,headerWidth-36.0);
    UILabel *name=[[UILabel alloc] initWithFrame:CGRectMake(18,70,textWidth,22)]; name.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold]; name.text=[self.profileData[@"name"] isKindOfClass:NSString.class]?self.profileData[@"name"]:@""; [header addSubview:name];
    UILabel *handle=[[UILabel alloc] initWithFrame:CGRectMake(18,93,textWidth,20)]; handle.font=[UIFont systemFontOfSize:14]; handle.textColor=UIColor.secondaryLabelColor; handle.text=[self.profileData[@"handle"] isKindOfClass:NSString.class]?self.profileData[@"handle"]:@""; [header addSubview:handle];
    UILabel *counts=[[UILabel alloc] initWithFrame:CGRectMake(18,121,textWidth,20)]; counts.font=[UIFont systemFontOfSize:13]; counts.textColor=UIColor.secondaryLabelColor;
    NSString *following=[self.profileData[@"following"] isKindOfClass:NSString.class]?self.profileData[@"following"]:@"";
    NSString *followers=[self.profileData[@"followers"] isKindOfClass:NSString.class]?self.profileData[@"followers"]:@"";
    NSDictionary *followerProbe=[self.profileData[@"followerProbe"] isKindOfClass:NSDictionary.class]?self.profileData[@"followerProbe"]:nil;
    NSDictionary *probeCounts=[followerProbe[@"counts"] isKindOfClass:NSDictionary.class]?followerProbe[@"counts"]:nil;
    NSNumber *friendsCount=[probeCounts[@"friends_count"] isKindOfClass:NSNumber.class]?probeCounts[@"friends_count"]:nil;
    NSNumber *followersCount=[probeCounts[@"followers_count"] isKindOfClass:NSNumber.class]?probeCounts[@"followers_count"]:nil;
    if(following.length==0&&friendsCount)following=friendsCount.stringValue;
    if(followers.length==0&&followersCount)followers=followersCount.stringValue;
    counts.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",following,followers]; [header addSubview:counts];
    return header;
}

- (void)presentInParent:(UIViewController *)parent { [parent addChildViewController:self]; self.view.frame=parent.view.bounds; self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [parent.view addSubview:self.view]; [self didMoveToParentViewController:parent]; [self.view layoutIfNeeded]; self.panelLeadingConstraint.constant=0; [UIView animateWithDuration:.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{self.dimmingView.alpha=1;[self.view layoutIfNeeded];} completion:nil]; }
- (void)dismissAnimated:(BOOL)animated { CGFloat width=self.panelView.bounds.size.width?:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86); self.panelLeadingConstraint.constant=-width; void(^changes)(void)=^{self.dimmingView.alpha=0;[self.view layoutIfNeeded];}; void(^completion)(BOOL)=^(BOOL finished){[self willMoveToParentViewController:nil];[self.view removeFromSuperview];[self removeFromParentViewController];}; if(animated)[UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:changes completion:completion]; else{changes();completion(YES);} }
- (void)backgroundTapped:(id)sender{if(!self.accountSelectionInFlight)[self dismissAnimated:YES];}
- (void)swipedClosed:(id)sender{if(!self.accountSelectionInFlight)[self dismissAnimated:YES];}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"drawer"];
    if(!cell)cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"drawer"];
    NSDictionary *item=self.items[indexPath.row];
    BOOL destructive=[item[@"destructive"] boolValue];
    UIColor *tint=destructive?UIColor.systemRedColor:UIColor.labelColor;
    cell.textLabel.text=item[@"title"];
    cell.textLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.textLabel.textColor=tint;
    cell.imageView.image=[UIImage systemImageNamed:item[@"icon"]];
    cell.imageView.tintColor=tint;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.accountSelectionInFlight)return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item=self.items[indexPath.row];
    id<NativeDrawerViewControllerDelegate> delegate=self.delegate;
    NSString *action=item[@"action"],*path=item[@"path"];
    if(!action&&!path)return;
    [self dismissAnimated:YES];
    if([action isEqual:@"profile"]&&[delegate respondsToSelector:@selector(nativeDrawerDidSelectNativeProfile:)]) [delegate nativeDrawerDidSelectNativeProfile:self];
    else if([action isEqual:@"settings"]) [delegate nativeDrawerDidSelectScarletSettings:self];
    else if(path) [delegate nativeDrawer:self didSelectPath:path];
}
@end
