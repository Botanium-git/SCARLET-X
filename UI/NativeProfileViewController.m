#import "NativeProfileViewController.h"

@interface NativeProfileViewController ()
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UIView *contentView;
@property(nonatomic,assign) NSInteger selectedProfileTab;
@end

@implementation NativeProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.title=@"プロフィール";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped:)];
    [self buildUI];
}

- (void)applyProfileData:(NSDictionary *)profileData {
    self.profileData=[profileData isKindOfClass:NSDictionary.class]?[profileData copy]:@{};
    if(!self.isViewLoaded)return;
    [self.scrollView removeFromSuperview];
    self.scrollView=nil;
    self.contentView=nil;
    [self buildUI];
}

- (NSString *)stringValue:(id)value {
    if([value isKindOfClass:NSString.class])return value;
    if([value isKindOfClass:NSNumber.class])return [(NSNumber *)value stringValue];
    return @"";
}

- (NSString *)displayDate:(NSString *)raw {
    if(raw.length==0)return @"";
    NSDateFormatter *input=[NSDateFormatter new];
    input.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    input.dateFormat=@"EEE MMM dd HH:mm:ss Z yyyy";
    NSDate *date=[input dateFromString:raw];
    if(!date)return raw;
    NSDateFormatter *output=[NSDateFormatter new];
    output.locale=[NSLocale currentLocale];
    output.dateFormat=@"M/d H:mm";
    return [output stringFromDate:date];
}

- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView {
    if(![urlString isKindOfClass:NSString.class]||urlString.length==0)return;
    NSURL *url=[NSURL URLWithString:urlString]; if(!url)return;
    __weak UIImageView *weakView=imageView;
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        if(!data)return;
        UIImage *image=[UIImage imageWithData:data]; if(!image)return;
        dispatch_async(dispatch_get_main_queue(),^{ weakView.image=image; });
    }] resume];
}

- (UIView *)postViewForPost:(NSDictionary *)post {
    UIStackView *stack=[UIStackView new];
    stack.axis=UILayoutConstraintAxisVertical;
    stack.spacing=8;
    stack.layoutMargins=UIEdgeInsetsMake(14,16,14,16);
    stack.layoutMarginsRelativeArrangement=YES;

    NSString *created=[self displayDate:[self stringValue:post[@"createdAt"]]];
    if(created.length){
        UILabel *date=[UILabel new];
        date.font=[UIFont systemFontOfSize:13];
        date.textColor=UIColor.secondaryLabelColor;
        date.text=created;
        [stack addArrangedSubview:date];
    }

    UILabel *body=[UILabel new];
    body.font=[UIFont systemFontOfSize:15];
    body.numberOfLines=0;
    body.text=[self stringValue:post[@"text"]];
    [stack addArrangedSubview:body];

    NSString *mediaURL=[self stringValue:post[@"mediaURL"]];
    if(mediaURL.length){
        UIImageView *media=[UIImageView new];
        media.translatesAutoresizingMaskIntoConstraints=NO;
        media.backgroundColor=UIColor.secondarySystemBackgroundColor;
        media.contentMode=UIViewContentModeScaleAspectFill;
        media.clipsToBounds=YES;
        media.layer.cornerRadius=12;
        [media.heightAnchor constraintEqualToConstant:220].active=YES;
        [stack addArrangedSubview:media];
        [self loadImageURLString:mediaURL into:media];
    }

    UIView *separator=[UIView new];
    separator.translatesAutoresizingMaskIntoConstraints=NO;
    separator.backgroundColor=UIColor.separatorColor;
    [separator.heightAnchor constraintEqualToConstant:.5].active=YES;
    [stack addArrangedSubview:separator];
    return stack;
}

- (void)profileTabTapped:(UIButton *)sender {
    NSInteger next=sender.tag;
    if(next<0||next>3||next==self.selectedProfileTab)return;
    self.selectedProfileTab=next;
    [self applyProfileData:self.profileData];
}

- (void)profileTabSwiped:(UISwipeGestureRecognizer *)gesture {
    NSInteger next=self.selectedProfileTab;
    if(gesture.direction==UISwipeGestureRecognizerDirectionLeft)next=MIN(3,next+1);
    else if(gesture.direction==UISwipeGestureRecognizerDirectionRight)next=MAX(0,next-1);
    if(next==self.selectedProfileTab)return;
    self.selectedProfileTab=next;
    [self applyProfileData:self.profileData];
}

- (UIView *)profileTabBar {
    NSArray<NSString *> *titles=@[@"ポスト",@"返信",@"ハイライト",@"メディア"];
    UIStackView *tabs=[UIStackView new];
    tabs.translatesAutoresizingMaskIntoConstraints=NO;
    tabs.axis=UILayoutConstraintAxisHorizontal;
    tabs.distribution=UIStackViewDistributionFillEqually;
    tabs.alignment=UIStackViewAlignmentFill;
    tabs.spacing=0;

    [titles enumerateObjectsUsingBlock:^(NSString *title,NSUInteger idx,BOOL *stop){
        UIView *container=[UIView new];
        container.translatesAutoresizingMaskIntoConstraints=NO;

        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints=NO;
        button.tag=(NSInteger)idx;
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font=[UIFont systemFontOfSize:15 weight:(idx==(NSUInteger)self.selectedProfileTab?UIFontWeightBold:UIFontWeightSemibold)];
        [button setTitleColor:(idx==(NSUInteger)self.selectedProfileTab?UIColor.labelColor:UIColor.secondaryLabelColor) forState:UIControlStateNormal];
        [button addTarget:self action:@selector(profileTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:button];

        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:container.topAnchor],
            [button.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [button.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];

        if(idx==(NSUInteger)self.selectedProfileTab){
            UIView *indicator=[UIView new];
            indicator.translatesAutoresizingMaskIntoConstraints=NO;
            indicator.backgroundColor=UIColor.systemBlueColor;
            indicator.layer.cornerRadius=1.5;
            [container addSubview:indicator];
            [NSLayoutConstraint activateConstraints:@[
                [indicator.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
                [indicator.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
                [indicator.widthAnchor constraintEqualToConstant:54],
                [indicator.heightAnchor constraintEqualToConstant:3]
            ]];
        }

        [tabs addArrangedSubview:container];
    }];
    return tabs;
}

- (void)buildUI {
    NSDictionary *data=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSDictionary *followerProbe=[data[@"followerProbe"] isKindOfClass:NSDictionary.class]?data[@"followerProbe"]:@{};
    NSDictionary *counts=[followerProbe[@"counts"] isKindOfClass:NSDictionary.class]?followerProbe[@"counts"]:@{};
    NSArray *posts=[data[@"posts"] isKindOfClass:NSArray.class]?data[@"posts"]:@[];
    BOOL postsLoading=[data[@"postsLoading"] respondsToSelector:@selector(boolValue)]?[data[@"postsLoading"] boolValue]:NO;

    NSString *name=[self stringValue:data[@"name"]];
    NSString *handle=[self stringValue:data[@"handle"]];
    NSString *bio=[self stringValue:data[@"bio"]];
    NSString *avatarURL=[self stringValue:data[@"avatarURL"]];
    NSString *bannerURL=[self stringValue:data[@"bannerURL"]];
    NSString *following=[self stringValue:data[@"following"]];
    NSString *followers=[self stringValue:data[@"followers"]];
    if(following.length==0)following=[self stringValue:counts[@"friends_count"]];
    if(following.length==0)following=[self stringValue:counts[@"legacy.friends_count"]];
    if(followers.length==0)followers=[self stringValue:counts[@"followers_count"]];
    if(followers.length==0)followers=[self stringValue:counts[@"legacy.followers_count"]];

    self.scrollView=[UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints=NO;
    self.scrollView.alwaysBounceVertical=YES;
    [self.view addSubview:self.scrollView];

    UISwipeGestureRecognizer *leftSwipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(profileTabSwiped:)];
    leftSwipe.direction=UISwipeGestureRecognizerDirectionLeft;
    [self.scrollView addGestureRecognizer:leftSwipe];
    UISwipeGestureRecognizer *rightSwipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(profileTabSwiped:)];
    rightSwipe.direction=UISwipeGestureRecognizerDirectionRight;
    [self.scrollView addGestureRecognizer:rightSwipe];

    self.contentView=[UIView new];
    self.contentView.translatesAutoresizingMaskIntoConstraints=NO;
    [self.scrollView addSubview:self.contentView];

    UIImageView *banner=[UIImageView new];
    banner.translatesAutoresizingMaskIntoConstraints=NO;
    banner.backgroundColor=UIColor.secondarySystemBackgroundColor;
    banner.contentMode=UIViewContentModeScaleAspectFill;
    banner.clipsToBounds=YES;
    [self.contentView addSubview:banner];
    [self loadImageURLString:bannerURL into:banner];

    UIImageView *avatar=[UIImageView new];
    avatar.translatesAutoresizingMaskIntoConstraints=NO;
    avatar.backgroundColor=UIColor.secondarySystemBackgroundColor;
    avatar.contentMode=UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds=YES;
    avatar.layer.cornerRadius=38;
    avatar.layer.borderWidth=4;
    avatar.layer.borderColor=UIColor.systemBackgroundColor.CGColor;
    avatar.image=[UIImage systemImageNamed:@"person.crop.circle.fill"];
    [self.contentView addSubview:avatar];
    [self loadImageURLString:avatarURL into:avatar];

    UIButton *editButton=[UIButton buttonWithType:UIButtonTypeSystem];
    editButton.translatesAutoresizingMaskIntoConstraints=NO;
    [editButton setTitle:@"プロフィールを編集" forState:UIControlStateNormal];
    editButton.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    editButton.layer.cornerRadius=18;
    editButton.layer.borderWidth=1;
    editButton.layer.borderColor=UIColor.separatorColor.CGColor;
    editButton.enabled=NO;
    editButton.alpha=.55;
    [self.contentView addSubview:editButton];

    UILabel *nameLabel=[UILabel new];
    nameLabel.translatesAutoresizingMaskIntoConstraints=NO;
    nameLabel.font=[UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    nameLabel.text=name;
    [self.contentView addSubview:nameLabel];

    UILabel *handleLabel=[UILabel new];
    handleLabel.translatesAutoresizingMaskIntoConstraints=NO;
    handleLabel.font=[UIFont systemFontOfSize:15];
    handleLabel.textColor=UIColor.secondaryLabelColor;
    handleLabel.text=handle;
    [self.contentView addSubview:handleLabel];

    UILabel *bioLabel=[UILabel new];
    bioLabel.translatesAutoresizingMaskIntoConstraints=NO;
    bioLabel.font=[UIFont systemFontOfSize:15];
    bioLabel.numberOfLines=0;
    bioLabel.text=bio;
    [self.contentView addSubview:bioLabel];

    UILabel *countsLabel=[UILabel new];
    countsLabel.translatesAutoresizingMaskIntoConstraints=NO;
    countsLabel.font=[UIFont systemFontOfSize:14];
    countsLabel.textColor=UIColor.secondaryLabelColor;
    NSString *safeFollowing=following.length?following:@"—";
    NSString *safeFollowers=followers.length?followers:@"—";
    countsLabel.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",safeFollowing,safeFollowers];
    [self.contentView addSubview:countsLabel];

    UIView *separator=[UIView new];
    separator.translatesAutoresizingMaskIntoConstraints=NO;
    separator.backgroundColor=UIColor.separatorColor;
    [self.contentView addSubview:separator];

    UIView *tabBar=[self profileTabBar];
    [self.contentView addSubview:tabBar];

    UIView *tabsBottomBorder=[UIView new];
    tabsBottomBorder.translatesAutoresizingMaskIntoConstraints=NO;
    tabsBottomBorder.backgroundColor=UIColor.separatorColor;
    [self.contentView addSubview:tabsBottomBorder];

    UIStackView *postsStack=[UIStackView new];
    postsStack.translatesAutoresizingMaskIntoConstraints=NO;
    postsStack.axis=UILayoutConstraintAxisVertical;
    postsStack.spacing=0;
    [self.contentView addSubview:postsStack];

    NSInteger added=0;
    if(self.selectedProfileTab==0){
        for(id item in posts){
            if(![item isKindOfClass:NSDictionary.class])continue;
            [postsStack addArrangedSubview:[self postViewForPost:(NSDictionary *)item]];
            added++;
        }
        if(added==0){
            UILabel *empty=[UILabel new];
            empty.font=[UIFont systemFontOfSize:14];
            empty.textColor=UIColor.secondaryLabelColor;
            empty.textAlignment=NSTextAlignmentCenter;
            empty.numberOfLines=0;
            empty.text=postsLoading?@"Xからポストを読み込み中…":@"通常ポストはありません";
            [postsStack addArrangedSubview:empty];
            [empty.heightAnchor constraintGreaterThanOrEqualToConstant:100].active=YES;
        }
    } else {
        UILabel *empty=[UILabel new];
        empty.font=[UIFont systemFontOfSize:14];
        empty.textColor=UIColor.secondaryLabelColor;
        empty.textAlignment=NSTextAlignmentCenter;
        empty.text=@"このタブのデータはまだ接続していません";
        [postsStack addArrangedSubview:empty];
        [empty.heightAnchor constraintGreaterThanOrEqualToConstant:120].active=YES;
    }

    UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [banner.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [banner.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [banner.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [banner.heightAnchor constraintEqualToConstant:150],

        [avatar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [avatar.centerYAnchor constraintEqualToAnchor:banner.bottomAnchor],
        [avatar.widthAnchor constraintEqualToConstant:76],
        [avatar.heightAnchor constraintEqualToConstant:76],

        [editButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [editButton.topAnchor constraintEqualToAnchor:banner.bottomAnchor constant:12],
        [editButton.heightAnchor constraintEqualToConstant:36],

        [nameLabel.topAnchor constraintEqualToAnchor:avatar.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [handleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [handleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [handleLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],

        [bioLabel.topAnchor constraintEqualToAnchor:handleLabel.bottomAnchor constant:14],
        [bioLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [bioLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],

        [countsLabel.topAnchor constraintEqualToAnchor:bioLabel.bottomAnchor constant:14],
        [countsLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [countsLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],

        [separator.topAnchor constraintEqualToAnchor:countsLabel.bottomAnchor constant:18],
        [separator.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:.5],

        [tabBar.topAnchor constraintEqualToAnchor:separator.bottomAnchor],
        [tabBar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [tabBar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [tabBar.heightAnchor constraintEqualToConstant:52],

        [tabsBottomBorder.topAnchor constraintEqualToAnchor:tabBar.bottomAnchor],
        [tabsBottomBorder.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [tabsBottomBorder.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [tabsBottomBorder.heightAnchor constraintEqualToConstant:.5],

        [postsStack.topAnchor constraintEqualToAnchor:tabsBottomBorder.bottomAnchor],
        [postsStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [postsStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [postsStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-30]
    ]];
}

- (void)closeTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
