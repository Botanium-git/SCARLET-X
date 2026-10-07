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
    [self buildUI];

    UIButton *back=[UIButton buttonWithType:UIButtonTypeSystem];
    back.translatesAutoresizingMaskIntoConstraints=NO;
    back.backgroundColor=[UIColor colorWithWhite:0 alpha:.58];
    back.tintColor=UIColor.whiteColor;
    back.layer.cornerRadius=19;
    [back setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:back];

    UIButton *search=[UIButton buttonWithType:UIButtonTypeSystem];
    search.translatesAutoresizingMaskIntoConstraints=NO;
    search.backgroundColor=[UIColor colorWithWhite:0 alpha:.58];
    search.tintColor=UIColor.whiteColor;
    search.layer.cornerRadius=19;
    [search setImage:[UIImage systemImageNamed:@"magnifyingglass"] forState:UIControlStateNormal];
    [search addTarget:self action:@selector(searchTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:search];

    UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [back.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [back.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [back.widthAnchor constraintEqualToConstant:38],
        [back.heightAnchor constraintEqualToConstant:38],
        [search.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [search.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [search.widthAnchor constraintEqualToConstant:38],
        [search.heightAnchor constraintEqualToConstant:38]
    ]];
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

- (NSString *)joinedTextForRaw:(NSString *)raw {
    if(raw.length==0)return @"";
    NSDateFormatter *input=[NSDateFormatter new];
    input.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    input.dateFormat=@"EEE MMM dd HH:mm:ss Z yyyy";
    NSDate *date=[input dateFromString:raw];
    if(!date)return @"";
    NSDateFormatter *output=[NSDateFormatter new];
    output.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"];
    output.dateFormat=@"yyyy年M月";
    return [NSString stringWithFormat:@"%@からXを利用しています",[output stringFromDate:date]];
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
    NSArray<NSString *> *symbols=@[@"list.bullet.rectangle",@"bubble",@"arrow.2.squarepath",@"rectangle.on.rectangle"];
    UIStackView *tabs=[UIStackView new];
    tabs.translatesAutoresizingMaskIntoConstraints=NO;
    tabs.axis=UILayoutConstraintAxisHorizontal;
    tabs.distribution=UIStackViewDistributionFillEqually;
    tabs.alignment=UIStackViewAlignmentFill;
    tabs.spacing=0;

    [symbols enumerateObjectsUsingBlock:^(NSString *symbol,NSUInteger idx,BOOL *stop){
        UIView *container=[UIView new];
        container.translatesAutoresizingMaskIntoConstraints=NO;

        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints=NO;
        button.tag=(NSInteger)idx;
        [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
        if(idx==0){
            [button setTitle:@"  ポスト" forState:UIControlStateNormal];
            button.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        }
        BOOL active=(idx==(NSUInteger)self.selectedProfileTab);
        UIColor *tint=active?UIColor.labelColor:UIColor.secondaryLabelColor;
        [button setTitleColor:tint forState:UIControlStateNormal];
        button.tintColor=tint;
        [button addTarget:self action:@selector(profileTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:button];

        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:container.topAnchor],
            [button.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [button.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];

        if(active){
            UIView *indicator=[UIView new];
            indicator.translatesAutoresizingMaskIntoConstraints=NO;
            indicator.backgroundColor=UIColor.labelColor;
            indicator.layer.cornerRadius=1.5;
            [container addSubview:indicator];
            [NSLayoutConstraint activateConstraints:@[
                [indicator.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
                [indicator.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
                [indicator.widthAnchor constraintEqualToConstant:(idx==0?108:48)],
                [indicator.heightAnchor constraintEqualToConstant:3]
            ]];
        }

        [tabs addArrangedSubview:container];
    }];
    return tabs;
}

- (UIButton *)profileActionButtonWithTitle:(NSString *)title {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints=NO;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.layer.cornerRadius=20;
    button.layer.borderWidth=1;
    button.layer.borderColor=UIColor.separatorColor.CGColor;
    return button;
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
    NSString *joined=[self stringValue:data[@"joinedText"]];
    if(joined.length==0)joined=[self joinedTextForRaw:[self stringValue:data[@"createdAt"]]];
    BOOL verified=[data[@"verified"] respondsToSelector:@selector(boolValue)]?[data[@"verified"] boolValue]:NO;
    BOOL protectedAccount=[data[@"protected"] respondsToSelector:@selector(boolValue)]?[data[@"protected"] boolValue]:NO;
    if(following.length==0)following=[self stringValue:counts[@"friends_count"]];
    if(following.length==0)following=[self stringValue:counts[@"legacy.friends_count"]];
    if(followers.length==0)followers=[self stringValue:counts[@"followers_count"]];
    if(followers.length==0)followers=[self stringValue:counts[@"legacy.followers_count"]];

    self.scrollView=[UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints=NO;
    self.scrollView.alwaysBounceVertical=YES;
    if(@available(iOS 11.0,*))self.scrollView.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
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

    UILabel *nameLabel=[UILabel new];
    nameLabel.translatesAutoresizingMaskIntoConstraints=NO;
    nameLabel.accessibilityIdentifier=@"sx.profile.name";
    // X profile appearance: fullNameFont -> UIFont.xds_bodyBold.
    nameLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    nameLabel.text=name;
    nameLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *nameRow=[UIStackView new];
    nameRow.translatesAutoresizingMaskIntoConstraints=NO;
    nameRow.accessibilityIdentifier=@"sx.profile.name.row";
    nameRow.axis=UILayoutConstraintAxisHorizontal;
    nameRow.alignment=UIStackViewAlignmentCenter;
    nameRow.spacing=2.5;
    [nameRow addArrangedSubview:nameLabel];

    if(verified){
        UIImageSymbolConfiguration *verifiedConfig=[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImageView *verifiedBadge=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill" withConfiguration:verifiedConfig]];
        verifiedBadge.translatesAutoresizingMaskIntoConstraints=NO;
        verifiedBadge.tintColor=UIColor.systemBlueColor;
        [nameRow addArrangedSubview:verifiedBadge];
        [verifiedBadge.widthAnchor constraintEqualToConstant:18].active=YES;
        [verifiedBadge.heightAnchor constraintEqualToConstant:18].active=YES;
    }
    if(protectedAccount){
        UIImageSymbolConfiguration *protectedConfig=[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        UIImageView *protectedBadge=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill" withConfiguration:protectedConfig]];
        protectedBadge.translatesAutoresizingMaskIntoConstraints=NO;
        protectedBadge.tintColor=UIColor.labelColor;
        [nameRow addArrangedSubview:protectedBadge];
        [protectedBadge.widthAnchor constraintEqualToConstant:18].active=YES;
        [protectedBadge.heightAnchor constraintEqualToConstant:18].active=YES;
    }
    UIButton *verify=[UIButton buttonWithType:UIButtonTypeSystem];
    verify.translatesAutoresizingMaskIntoConstraints=NO;
    verify.accessibilityIdentifier=@"sx.profile.verify";
    [verify setTitle:@"認証を受ける" forState:UIControlStateNormal];
    [verify setImage:[UIImage systemImageNamed:@"checkmark.seal.fill"] forState:UIControlStateNormal];
    verify.tintColor=UIColor.systemBlueColor;
    [verify setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    verify.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    verify.layer.cornerRadius=15;
    verify.layer.borderWidth=1;
    verify.layer.borderColor=UIColor.separatorColor.CGColor;
    [verify setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [verify setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [nameRow addArrangedSubview:verify];
    [verify.heightAnchor constraintEqualToConstant:30].active=YES;

    [self.contentView addSubview:nameRow];

    UILabel *handleLabel=[UILabel new];
    handleLabel.translatesAutoresizingMaskIntoConstraints=NO;
    handleLabel.accessibilityIdentifier=@"sx.profile.handle";
    // X profile appearance: usernameFont -> xds_spoofingResistantUsername_body.
    handleLabel.font=[UIFont systemFontOfSize:14];
    handleLabel.textColor=UIColor.secondaryLabelColor;
    handleLabel.text=handle;
    [self.contentView addSubview:handleLabel];

    UILabel *bioLabel=[UILabel new];
    bioLabel.translatesAutoresizingMaskIntoConstraints=NO;
    bioLabel.accessibilityIdentifier=@"sx.profile.bio";
    // X profile appearance: bioFont -> UIFont.xds_body.
    bioLabel.font=[UIFont systemFontOfSize:14];
    bioLabel.numberOfLines=0;
    bioLabel.text=bio;
    [self.contentView addSubview:bioLabel];

    UIView *joinedContainer=[UIView new];
    joinedContainer.translatesAutoresizingMaskIntoConstraints=NO;
    joinedContainer.accessibilityIdentifier=@"sx.profile.joined.container";
    [self.contentView addSubview:joinedContainer];
    UIImageView *calendar=[UIImageView new];
    calendar.translatesAutoresizingMaskIntoConstraints=NO;
    calendar.image=[UIImage systemImageNamed:@"calendar"];
    calendar.tintColor=UIColor.secondaryLabelColor;
    [joinedContainer addSubview:calendar];
    UILabel *joinedLabel=[UILabel new];
    joinedLabel.translatesAutoresizingMaskIntoConstraints=NO;
    joinedLabel.accessibilityIdentifier=@"sx.profile.joined.label";
    joinedLabel.font=[UIFont systemFontOfSize:13];
    joinedLabel.textColor=UIColor.secondaryLabelColor;
    joinedLabel.text=joined;
    [joinedContainer addSubview:joinedLabel];
    UIImageView *joinedChevron=[UIImageView new];
    joinedChevron.translatesAutoresizingMaskIntoConstraints=NO;
    joinedChevron.image=[UIImage systemImageNamed:@"chevron.right"];
    joinedChevron.tintColor=UIColor.tertiaryLabelColor;
    joinedChevron.contentMode=UIViewContentModeScaleAspectFit;
    [joinedContainer addSubview:joinedChevron];
    [NSLayoutConstraint activateConstraints:@[
        [calendar.leadingAnchor constraintEqualToAnchor:joinedContainer.leadingAnchor],
        [calendar.centerYAnchor constraintEqualToAnchor:joinedContainer.centerYAnchor],
        [calendar.widthAnchor constraintEqualToConstant:16],
        [calendar.heightAnchor constraintEqualToConstant:16],
        [joinedLabel.leadingAnchor constraintEqualToAnchor:calendar.trailingAnchor constant:6],
        [joinedLabel.centerYAnchor constraintEqualToAnchor:joinedContainer.centerYAnchor],
        [joinedChevron.leadingAnchor constraintEqualToAnchor:joinedLabel.trailingAnchor constant:4],
        [joinedChevron.centerYAnchor constraintEqualToAnchor:joinedContainer.centerYAnchor],
        [joinedChevron.widthAnchor constraintEqualToConstant:8],
        [joinedChevron.heightAnchor constraintEqualToConstant:12],
        [joinedChevron.trailingAnchor constraintLessThanOrEqualToAnchor:joinedContainer.trailingAnchor]
    ]];
    NSLayoutConstraint *joinedHeight=[joinedContainer.heightAnchor constraintEqualToConstant:(joined.length?20:0)];
    joinedHeight.identifier=@"sx.profile.joined.height";
    joinedHeight.active=YES;

    UILabel *countsLabel=[UILabel new];
    countsLabel.translatesAutoresizingMaskIntoConstraints=NO;
    countsLabel.accessibilityIdentifier=@"sx.profile.counts";
    countsLabel.font=[UIFont systemFontOfSize:14];
    countsLabel.textColor=UIColor.secondaryLabelColor;
    NSString *safeFollowing=following.length?following:@"—";
    NSString *safeFollowers=followers.length?followers:@"—";
    countsLabel.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",safeFollowing,safeFollowers];
    [self.contentView addSubview:countsLabel];

    UIStackView *actions=[UIStackView new];
    actions.translatesAutoresizingMaskIntoConstraints=NO;
    actions.axis=UILayoutConstraintAxisHorizontal;
    actions.spacing=8;
    actions.distribution=UIStackViewDistributionFillEqually;
    [actions addArrangedSubview:[self profileActionButtonWithTitle:@"プロフィールを共有"]];
    [actions addArrangedSubview:[self profileActionButtonWithTitle:@"プロフィールを編集"]];
    [self.contentView addSubview:actions];

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

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
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
        [banner.heightAnchor constraintEqualToConstant:156],

        [avatar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [avatar.centerYAnchor constraintEqualToAnchor:banner.bottomAnchor constant:24],
        [avatar.widthAnchor constraintEqualToConstant:76],
        [avatar.heightAnchor constraintEqualToConstant:76],

        [nameRow.topAnchor constraintEqualToAnchor:avatar.bottomAnchor constant:14],
        [nameRow.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [nameRow.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [handleLabel.topAnchor constraintEqualToAnchor:nameRow.bottomAnchor constant:3],
        [handleLabel.leadingAnchor constraintEqualToAnchor:nameRow.leadingAnchor],
        [handleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [bioLabel.topAnchor constraintEqualToAnchor:handleLabel.bottomAnchor constant:16],
        [bioLabel.leadingAnchor constraintEqualToAnchor:nameRow.leadingAnchor],
        [bioLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [joinedContainer.topAnchor constraintEqualToAnchor:bioLabel.bottomAnchor constant:12],
        [joinedContainer.leadingAnchor constraintEqualToAnchor:nameRow.leadingAnchor],
        [joinedContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [countsLabel.topAnchor constraintEqualToAnchor:joinedContainer.bottomAnchor constant:10],
        [countsLabel.leadingAnchor constraintEqualToAnchor:nameRow.leadingAnchor],
        [countsLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [actions.topAnchor constraintEqualToAnchor:countsLabel.bottomAnchor constant:18],
        [actions.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [actions.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [actions.heightAnchor constraintEqualToConstant:42],

        [separator.topAnchor constraintEqualToAnchor:actions.bottomAnchor constant:14],
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

- (void)searchTapped:(id)sender {
    // Native search wiring comes later; keep the official control visible without changing navigation yet.
}

@end
