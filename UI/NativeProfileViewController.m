#import "NativeProfileViewController.h"

@interface NativeProfileViewController ()
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UIView *contentView;
@end

@implementation NativeProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.title=@"プロフィール";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped:)];
    [self buildUI];
}

- (NSString *)stringValue:(id)value {
    if([value isKindOfClass:NSString.class])return value;
    if([value isKindOfClass:NSNumber.class])return [(NSNumber *)value stringValue];
    return @"";
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

- (void)buildUI {
    NSDictionary *data=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSDictionary *followerProbe=[data[@"followerProbe"] isKindOfClass:NSDictionary.class]?data[@"followerProbe"]:@{};
    NSDictionary *counts=[followerProbe[@"counts"] isKindOfClass:NSDictionary.class]?followerProbe[@"counts"]:@{};

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
    editButton.contentEdgeInsets=UIEdgeInsetsMake(7,14,7,14);
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

    UILabel *phaseLabel=[UILabel new];
    phaseLabel.translatesAutoresizingMaskIntoConstraints=NO;
    phaseLabel.font=[UIFont systemFontOfSize:14];
    phaseLabel.textColor=UIColor.secondaryLabelColor;
    phaseLabel.textAlignment=NSTextAlignmentCenter;
    phaseLabel.numberOfLines=0;
    phaseLabel.text=@"プロフィール上部をネイティブ表示中\n投稿一覧は次の段階で追加";
    [self.contentView addSubview:phaseLabel];

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

        [phaseLabel.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:28],
        [phaseLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [phaseLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [phaseLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-40]
    ]];
}

- (void)closeTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
