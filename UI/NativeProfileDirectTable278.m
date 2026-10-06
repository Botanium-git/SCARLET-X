#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AVKit/AVKit.h>

static char SX278AdapterKey;
static char SX278TableKey;
static char SX278LastRequestKey;

typedef void (*SX278SetProfileDataIMP)(id, SEL, NSDictionary *);
static SX278SetProfileDataIMP SX278PreviousSetProfileDataIMP = NULL;
typedef void (*SX278ViewDidLoadIMP)(id, SEL);
static SX278ViewDidLoadIMP SX278PreviousViewDidLoadIMP = NULL;
typedef void (*SX278ViewDidLayoutIMP)(id, SEL);
static SX278ViewDidLayoutIMP SX278PreviousViewDidLayoutIMP = NULL;

@interface NativeProfileViewController (SX278Private)
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
- (void)profileTabSwiped:(UISwipeGestureRecognizer *)gesture;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NSString *SX278String(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    return @"";
}

static NSInteger SX278XContentSizeCategoryOffset(UIContentSizeCategory category) {
    if ([category isEqualToString:UIContentSizeCategoryExtraSmall]) return -2;
    if ([category isEqualToString:UIContentSizeCategorySmall]) return -1;
    if ([category isEqualToString:UIContentSizeCategoryMedium]) return 0;
    if ([category isEqualToString:UIContentSizeCategoryLarge]) return 0;
    if ([category isEqualToString:UIContentSizeCategoryExtraLarge]) return 1;
    if ([category isEqualToString:UIContentSizeCategoryExtraExtraLarge]) return 3;
    if ([category isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]) return 6;
    if ([category isEqualToString:UIContentSizeCategoryAccessibilityMedium]) return 10;
    if ([category isEqualToString:UIContentSizeCategoryAccessibilityLarge]) return 15;
    if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraLarge]) return 20;
    if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraLarge]) return 25;
    if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) return 30;
    return 0;
}

static NSInteger SX278XWindowSizeClass(CGSize size) {
    CGFloat shortSide = MIN(fabs(size.width), fabs(size.height));
    if (shortSide < 376.0) return 0;
    if (shortSide < 401.0) return 1;
    if (shortSide < 513.0) return 2;
    return 3;
}

static CGFloat SX278XContentFontSize(void) {
    UIContentSizeCategory category = UIScreen.mainScreen.traitCollection.preferredContentSizeCategory;
    NSInteger categoryOffset = SX278XContentSizeCategoryOffset(category);
    NSInteger contentSizeModifier = [[NSUserDefaults standardUserDefaults] integerForKey:@"TweetieContentSizeModifierPreferencesKey"];
    NSInteger windowSizeClass = SX278XWindowSizeClass(UIScreen.mainScreen.bounds.size);
    return nearbyint(14.0 + (CGFloat)categoryOffset + (CGFloat)contentSizeModifier + (CGFloat)windowSizeClass);
}

static UIFont *SX278XFont(UIFontWeight weight) {
    return [UIFont systemFontOfSize:SX278XContentFontSize() weight:weight];
}

static NSString *SX278CompactCount(NSInteger value) {
    if (value <= 0) return @"";
    if (value < 10000) return [NSString stringWithFormat:@"%ld", (long)value];
    double unit = 10000.0;
    NSString *suffix = @"万";
    if (value >= 100000000) {
        unit = 100000000.0;
        suffix = @"億";
    }
    double scaled = (double)value / unit;
    double rounded = round(scaled * 10.0) / 10.0;
    if (fabs(rounded - round(rounded)) < 0.0001) {
        return [NSString stringWithFormat:@"%.0f%@", rounded, suffix];
    }
    return [NSString stringWithFormat:@"%.1f%@", rounded, suffix];
}

static CGFloat SX278SocialProofFontSize(CGFloat width) {
    if (width <= 320.0) return 12.0;
    if (width <= 375.0) return 13.0;
    if (width <= 414.0) return 14.0;
    return 15.0;
}

static CGFloat SX278SocialProofHeight(CGFloat width) {
    UIFont *font = [UIFont systemFontOfSize:SX278SocialProofFontSize(width)];
    return ceil(font.lineHeight);
}

static NSString *SX278Date(NSString *raw) {
    if (raw.length == 0) return @"";
    static NSDateFormatter *input;
    static NSDateFormatter *output;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        input = [NSDateFormatter new];
        input.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        input.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
        output = [NSDateFormatter new];
        output.locale = [NSLocale currentLocale];
        output.dateFormat = @"yyyy/MM/dd";
    });
    NSDate *date = [input dateFromString:raw];
    if (!date) return @"";

    NSTimeInterval delta = [[NSDate date] timeIntervalSinceDate:date];
    if (delta >= 0.0 && delta < 7.0 * 24.0 * 60.0 * 60.0) {
        NSInteger seconds = (NSInteger)floor(delta);
        if (seconds < 60) return @"今";
        NSInteger minutes = MAX(1, seconds / 60);
        if (minutes < 60) return [NSString stringWithFormat:@"%ld分", (long)minutes];
        NSInteger hours = minutes / 60;
        if (hours < 24) return [NSString stringWithFormat:@"%ld時間", (long)hours];
        NSInteger days = hours / 24;
        return [NSString stringWithFormat:@"%ld日", (long)MAX(1, days)];
    }

    return [output stringFromDate:date];
}

static CGSize SX278MediaSize(NSDictionary *post, CGFloat contentWidth, CGFloat rowWidth) {
    NSArray *media = [post[@"media"] isKindOfClass:NSArray.class] ? post[@"media"] : @[];
    if (media.count == 0 && SX278String(post[@"mediaURL"]).length) return CGSizeMake(contentWidth, 220.0);
    NSUInteger count = MIN(media.count, (NSUInteger)4);
    if (count == 0) return CGSizeZero;
    if (count == 1) {
        NSDictionary *item = [media.firstObject isKindOfClass:NSDictionary.class] ? media.firstObject : @{};
        CGFloat sourceW = [item[@"width"] respondsToSelector:@selector(doubleValue)] ? [item[@"width"] doubleValue] : 0.0;
        CGFloat sourceH = [item[@"height"] respondsToSelector:@selector(doubleValue)] ? [item[@"height"] doubleValue] : 0.0;
        if (sourceW > 0.0 && sourceH > 0.0) {
            CGFloat width = MAX(1.0, contentWidth);
            CGFloat aspect = sourceW / sourceH;
            if (aspect > 0.0 && aspect < 1.0) {
                const CGFloat baseWidthRatio = 0.7;
                const CGFloat videoAspect = 1.7778;
                const CGFloat minimumDisplayAspect = 0.46153846153846156;
                CGFloat height = MIN(width / aspect, width * baseWidthRatio * videoAspect);
                CGFloat mediaWidth = aspect * height;
                mediaWidth = MAX(mediaWidth, height * minimumDisplayAspect);
                mediaWidth = MIN(width, mediaWidth);
                return CGSizeMake(ceil(mediaWidth), ceil(height));
            }
            CGFloat clampedAspect = MAX(0.75, MIN(5.0, aspect));
            return CGSizeMake(width, ceil(width / clampedAspect));
        }
        return CGSizeMake(contentWidth, 220.0);
    }
    return CGSizeMake(contentWidth, ceil(MAX(1.0, rowWidth) * 0.68));
}

static CGFloat SX278TextHeight(NSString *text, CGFloat width) {
    if (text.length == 0) return 0.0;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAX(1.0, width), CGFLOAT_MAX)
                                    options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                 attributes:@{NSFontAttributeName:SX278XFont(UIFontWeightRegular)}
                                    context:nil];
    return ceil(rect.size.height);
}

static CGFloat SX278PostHeight(NSDictionary *post, CGFloat width) {
    BOOL repost = [post[@"isRepost"] respondsToSelector:@selector(boolValue)] && [post[@"isRepost"] boolValue];
    CGFloat h = repost ? SX278SocialProofHeight(width) : 0.0;
    CGFloat contentWidth = MAX(80.0, width - 56.0 - 12.0);
    CGFloat headerHeight = ceil(MAX(SX278XFont(UIFontWeightBold).lineHeight, SX278XFont(UIFontWeightRegular).lineHeight));
    CGFloat row = 8.0 + headerHeight;
    NSString *text = SX278String(post[@"text"]);
    CGFloat textH = SX278TextHeight(text, contentWidth);
    CGFloat mediaH = SX278MediaSize(post, MAX(1.0, contentWidth - 4.0), MAX(1.0, width - 4.0)).height;
    if (textH > 0.0) row += 2.0 + textH;
    if (mediaH > 0.0) row += 6.0 + mediaH;
    row += 4.0 + 28.0 + 8.0;
    h += MAX(59.0, row) + 0.5;
    return ceil(h);
}

static NSArray *SX278ItemsForTab(NSDictionary *data, NSInteger tab) {
    if (tab < 0 || tab > 3) return @[];
    NSArray *keys = @[@"posts", @"replies", @"reposts", @"media"];
    id value = data[keys[(NSUInteger)tab]];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSString *SX278ItemID(id item) {
    if (![item isKindOfClass:NSDictionary.class]) return @"";
    return SX278String(((NSDictionary *)item)[@"id"]);
}

static BOOL SX278SamePrefix(NSArray *oldItems, NSArray *newItems) {
    if (oldItems.count > newItems.count) return NO;
    for (NSUInteger i = 0; i < oldItems.count; i++) {
        NSString *a = SX278ItemID(oldItems[i]);
        NSString *b = SX278ItemID(newItems[i]);
        if (a.length == 0 || b.length == 0 || ![a isEqualToString:b]) return NO;
    }
    return YES;
}

@interface SX278MediaTile : UIControl
@property(nonatomic,strong) UIImageView *imageView;
@property(nonatomic,strong) UIImageView *playView;
@property(nonatomic,copy) NSString *videoURL;
@end
@implementation SX278MediaTile
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.clipsToBounds = YES;
        self.backgroundColor = UIColor.secondarySystemBackgroundColor;
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
        _playView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
        _playView.tintColor = UIColor.whiteColor;
        _playView.contentMode = UIViewContentModeScaleAspectFit;
        _playView.hidden = YES;
        [self addSubview:_playView];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    self.playView.frame = CGRectMake((self.bounds.size.width - 44.0) / 2.0,
                                     (self.bounds.size.height - 44.0) / 2.0,
                                     44.0, 44.0);
}
@end

@interface SX278PostCell : UITableViewCell
@property(nonatomic,weak) NativeProfileViewController *profile;
@property(nonatomic,strong) UIImageView *repostIcon;
@property(nonatomic,strong) UILabel *repostLabel;
@property(nonatomic,strong) UIImageView *avatar;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *metaLabel;
@property(nonatomic,strong) UIImageView *verifiedBadge;
@property(nonatomic,strong) UIImageView *protectedBadge;
@property(nonatomic,strong) UIImageView *moreView;
@property(nonatomic,strong) UILabel *bodyLabel;
@property(nonatomic,strong) UIScrollView *mediaContainer;
@property(nonatomic,strong) NSArray<SX278MediaTile *> *tiles;
@property(nonatomic,strong) NSArray<UIImageView *> *actionIcons;
@property(nonatomic,strong) NSArray<UILabel *> *actionLabels;
@property(nonatomic,strong) UIView *separator;
@property(nonatomic,strong) NSDictionary *post;
@end

@implementation SX278PostCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.systemBackgroundColor;
        self.contentView.backgroundColor = UIColor.systemBackgroundColor;

        _repostIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.2.squarepath"]];
        _repostIcon.tintColor = UIColor.secondaryLabelColor;
        _repostIcon.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_repostIcon];
        _repostLabel = [UILabel new];
        _repostLabel.font = [UIFont systemFontOfSize:14];
        _repostLabel.textColor = UIColor.secondaryLabelColor;
        [self.contentView addSubview:_repostLabel];

        _avatar = [UIImageView new];
        _avatar.backgroundColor = UIColor.secondarySystemBackgroundColor;
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.clipsToBounds = YES;
        _avatar.layer.cornerRadius = 20.0;
        [self.contentView addSubview:_avatar];

        _nameLabel = [UILabel new];
        _nameLabel.font = SX278XFont(UIFontWeightBold);
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLabel];
        _metaLabel = [UILabel new];
        _metaLabel.font = SX278XFont(UIFontWeightRegular);
        _metaLabel.textColor = UIColor.secondaryLabelColor;
        _metaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_metaLabel];
        UIImageSymbolConfiguration *verifiedConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightSemibold];
        _verifiedBadge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill" withConfiguration:verifiedConfig]];
        _verifiedBadge.tintColor = UIColor.systemBlueColor;
        _verifiedBadge.contentMode = UIViewContentModeScaleAspectFit;
        _verifiedBadge.hidden = YES;
        [self.contentView addSubview:_verifiedBadge];
        UIImageSymbolConfiguration *protectedConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        _protectedBadge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill" withConfiguration:protectedConfig]];
        _protectedBadge.tintColor = UIColor.secondaryLabelColor;
        _protectedBadge.contentMode = UIViewContentModeScaleAspectFit;
        _protectedBadge.hidden = YES;
        [self.contentView addSubview:_protectedBadge];
        _moreView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"]];
        _moreView.tintColor = UIColor.secondaryLabelColor;
        _moreView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_moreView];

        _bodyLabel = [UILabel new];
        _bodyLabel.font = SX278XFont(UIFontWeightRegular);
        _bodyLabel.numberOfLines = 0;
        _bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:_bodyLabel];

        _mediaContainer = [UIScrollView new];
        _mediaContainer.clipsToBounds = YES;
        _mediaContainer.layer.cornerRadius = 12.0;
        _mediaContainer.showsHorizontalScrollIndicator = NO;
        _mediaContainer.showsVerticalScrollIndicator = NO;
        _mediaContainer.alwaysBounceHorizontal = NO;
        _mediaContainer.alwaysBounceVertical = NO;
        [self.contentView addSubview:_mediaContainer];
        NSMutableArray *tiles = [NSMutableArray array];
        for (int i = 0; i < 4; i++) {
            SX278MediaTile *tile = [SX278MediaTile new];
            tile.hidden = YES;
            [tile addTarget:self action:@selector(mediaTapped:) forControlEvents:UIControlEventTouchUpInside];
            [_mediaContainer addSubview:tile];
            [tiles addObject:tile];
        }
        _tiles = tiles;

        NSArray *symbols = @[@"bubble", @"arrow.2.squarepath", @"heart", @"chart.bar", @"bookmark", @"square.and.arrow.up"];
        NSMutableArray *icons = [NSMutableArray array];
        NSMutableArray *labels = [NSMutableArray array];
        for (NSString *symbol in symbols) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
            iv.tintColor = UIColor.secondaryLabelColor;
            iv.contentMode = UIViewContentModeScaleAspectFit;
            [self.contentView addSubview:iv];
            [icons addObject:iv];
            UILabel *label = [UILabel new];
            label.font = [UIFont systemFontOfSize:12];
            label.textColor = UIColor.secondaryLabelColor;
            [self.contentView addSubview:label];
            [labels addObject:label];
        }
        _actionIcons = icons;
        _actionLabels = labels;
        _separator = [UIView new];
        _separator.backgroundColor = UIColor.separatorColor;
        [self.contentView addSubview:_separator];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatar.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    for (SX278MediaTile *tile in self.tiles) {
        tile.imageView.image = nil;
        tile.videoURL = nil;
        tile.playView.hidden = YES;
        tile.hidden = YES;
    }
}

- (void)configureWithPost:(NSDictionary *)post profile:(NativeProfileViewController *)profile {
    self.post = post;
    self.profile = profile;
    NSDictionary *pd = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSString *name = SX278String(post[@"authorName"]);
    if (!name.length) name = SX278String(pd[@"name"]);
    NSString *handle = SX278String(post[@"authorHandle"]);
    if (!handle.length) handle = SX278String(pd[@"handle"]);
    if (handle.length && ![handle hasPrefix:@"@"]) handle = [@"@" stringByAppendingString:handle];
    NSString *avatarURL = SX278String(post[@"authorAvatarURL"]);
    if (!avatarURL.length) avatarURL = SX278String(pd[@"avatarURL"]);

    self.nameLabel.text = name;
    NSString *date = SX278Date(SX278String(post[@"createdAt"]));
    self.metaLabel.text = (handle.length && date.length) ? [NSString stringWithFormat:@"%@ · %@", handle, date] : (handle.length ? handle : date);
    self.bodyLabel.text = SX278String(post[@"text"]);
    BOOL hasAuthorIdentity = SX278String(post[@"authorName"]).length || SX278String(post[@"authorHandle"]).length;
    BOOL verified = [post[@"authorVerified"] respondsToSelector:@selector(boolValue)] ? [post[@"authorVerified"] boolValue] : (!hasAuthorIdentity && [pd[@"verified"] respondsToSelector:@selector(boolValue)] ? [pd[@"verified"] boolValue] : NO);
    BOOL protectedAccount = [post[@"authorProtected"] respondsToSelector:@selector(boolValue)] ? [post[@"authorProtected"] boolValue] : (!hasAuthorIdentity && [pd[@"protected"] respondsToSelector:@selector(boolValue)] ? [pd[@"protected"] boolValue] : NO);
    self.verifiedBadge.hidden = !verified;
    self.protectedBadge.hidden = !protectedAccount;

    BOOL repost = [post[@"isRepost"] respondsToSelector:@selector(boolValue)] && [post[@"isRepost"] boolValue];
    NSString *profileName = SX278String(pd[@"name"]);
    self.repostIcon.hidden = !repost;
    self.repostLabel.hidden = !repost;
    if (repost) {
        CGFloat proofSize = SX278SocialProofFontSize(CGRectGetWidth(profile.view.bounds));
        UIFont *regular = [UIFont systemFontOfSize:proofSize];
        UIFont *bold = [UIFont systemFontOfSize:proofSize weight:UIFontWeightBold];
        NSDictionary *probe = [pd[@"followerProbe"] isKindOfClass:NSDictionary.class] ? pd[@"followerProbe"] : @{};
        NSString *currentUserId = SX278String(probe[@"currentUserId"]);
        NSString *displayedUserId = SX278String(pd[@"userId"]);
        NSString *currentScreen = SX278String(probe[@"currentScreen"]);
        NSString *displayedHandle = SX278String(pd[@"handle"]);
        if ([displayedHandle hasPrefix:@"@"]) displayedHandle = [displayedHandle substringFromIndex:1];
        BOOL isOwnProfile = (currentUserId.length && displayedUserId.length && [currentUserId isEqualToString:displayedUserId]) || (currentScreen.length && displayedHandle.length && [currentScreen caseInsensitiveCompare:displayedHandle] == NSOrderedSame);
        NSString *suffix = profileName.length ? @"さんがリポスト" : @"リポスト";
        NSString *full = isOwnProfile ? @"あなたがリポストしました" : (profileName.length ? [profileName stringByAppendingString:suffix] : suffix);
        NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:full
                                                                                       attributes:@{
            NSFontAttributeName: regular,
            NSForegroundColorAttributeName: UIColor.secondaryLabelColor
        }];
        if (!isOwnProfile && profileName.length) {
            [attributed addAttribute:NSFontAttributeName value:bold range:NSMakeRange(0, profileName.length)];
        }
        self.repostLabel.attributedText = attributed;
    } else {
        self.repostLabel.attributedText = nil;
        self.repostLabel.text = @"";
    }

    self.avatar.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    if (avatarURL.length) [profile loadImageURLString:avatarURL into:self.avatar];

    NSArray *media = [post[@"media"] isKindOfClass:NSArray.class] ? post[@"media"] : @[];
    if (media.count == 0) {
        NSString *legacy = SX278String(post[@"mediaURL"]);
        if (legacy.length) media = @[@{@"type":@"photo", @"previewURL":legacy}];
    }
    NSUInteger count = MIN(media.count, (NSUInteger)4);
    self.mediaContainer.hidden = (count == 0);
    for (NSUInteger i = 0; i < 4; i++) {
        SX278MediaTile *tile = self.tiles[i];
        tile.hidden = (i >= count);
        tile.imageView.image = nil;
        tile.videoURL = nil;
        tile.playView.hidden = YES;
        if (i < count) {
            NSDictionary *m = [media[i] isKindOfClass:NSDictionary.class] ? media[i] : @{};
            NSString *preview = SX278String(m[@"previewURL"]);
            if (preview.length) [profile loadImageURLString:preview into:tile.imageView];
            NSString *type = SX278String(m[@"type"]);
            NSString *video = SX278String(m[@"videoURL"]);
            BOOL playable = ([type isEqualToString:@"video"] || [type isEqualToString:@"animated_gif"]) && video.length;
            tile.videoURL = playable ? video : nil;
            tile.playView.hidden = !playable;
        }
    }

    NSArray *counts = @[post[@"replyCount"] ?: @0, post[@"retweetCount"] ?: @0, post[@"favoriteCount"] ?: @0, @0, @0, @0];
    for (NSUInteger i = 0; i < 6; i++) {
        NSInteger v = [counts[i] respondsToSelector:@selector(integerValue)] ? [counts[i] integerValue] : 0;
        self.actionLabels[i].text = SX278CompactCount(v);
    }
    [self setNeedsLayout];
}

- (void)mediaTapped:(SX278MediaTile *)sender {
    if (sender.videoURL.length == 0 || !self.profile) return;
    NSURL *url = [NSURL URLWithString:sender.videoURL];
    if (!url) return;
    AVPlayer *player = [AVPlayer playerWithURL:url];
    AVPlayerViewController *vc = [AVPlayerViewController new];
    vc.player = player;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.profile presentViewController:vc animated:YES completion:^{ [player play]; }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = CGRectGetWidth(self.contentView.bounds);
    BOOL repost = !self.repostLabel.hidden;
    CGFloat y = 0.0;
    if (repost) {
        CGFloat proofHeight = SX278SocialProofHeight(w);
        CGFloat proofFontSize = SX278SocialProofFontSize(w);
        self.repostLabel.font = [UIFont systemFontOfSize:proofFontSize];
        CGFloat labelHeight = ceil(self.repostLabel.font.lineHeight);
        CGFloat iconY = MAX(3.0, floor((proofHeight - 12.0) * 0.5));
        CGFloat labelY = MAX(1.0, floor((proofHeight - labelHeight) * 0.5));
        self.repostIcon.frame = CGRectMake(36.0, iconY, 12.0, 12.0);
        self.repostLabel.frame = CGRectMake(56.0, labelY, MAX(0.0, w - 68.0), labelHeight);
        y = proofHeight;
    } else {
        self.repostIcon.frame = CGRectZero;
        self.repostLabel.frame = CGRectZero;
    }

    self.avatar.layer.cornerRadius = 19.0;
    self.avatar.frame = CGRectMake(11.0, y + 8.0, 38.0, 38.0);
    CGFloat x = 56.0;
    CGFloat cw = MAX(80.0, w - x - 12.0);
    CGFloat headerY = y + 8.0;
    CGFloat headerHeight = ceil(MAX(self.nameLabel.font.lineHeight, self.metaLabel.font.lineHeight));
    CGFloat moreW = 18.0;
    self.moreView.frame = CGRectMake(x + cw - moreW, headerY, moreW, headerHeight);
    CGFloat textAvail = MAX(20.0, cw - moreW - 12.0);
    CGFloat verifiedW = self.verifiedBadge.hidden ? 0.0 : 15.0;
    CGFloat protectedW = self.protectedBadge.hidden ? 0.0 : 12.0;
    CGFloat accessoryW = 0.0;
    if (verifiedW > 0.0) accessoryW += 3.0 + verifiedW;
    if (protectedW > 0.0) accessoryW += 3.0 + protectedW;
    CGFloat nameNatural = ceil([self.nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, headerHeight)].width);
    CGFloat metaNatural = ceil([self.metaLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, headerHeight)].width);
    CGFloat nameW = MIN(nameNatural, MAX(20.0, textAvail - accessoryW));
    CGFloat metaW = MIN(metaNatural, MAX(0.0, textAvail - nameW - accessoryW - 4.0));
    if (nameNatural + accessoryW + 4.0 + metaNatural > textAvail) {
        nameW = MIN(nameNatural, floor(MAX(20.0, textAvail - accessoryW) * 0.42));
        metaW = MAX(0.0, textAvail - nameW - accessoryW - 4.0);
    }
    self.nameLabel.frame = CGRectMake(x, headerY, nameW, headerHeight);
    CGFloat accessoryX = x + nameW;
    if (verifiedW > 0.0) {
        accessoryX += 3.0;
        self.verifiedBadge.frame = CGRectMake(accessoryX, headerY + floor((headerHeight - 15.0) * 0.5), 15.0, 15.0);
        accessoryX += 15.0;
    } else {
        self.verifiedBadge.frame = CGRectZero;
    }
    if (protectedW > 0.0) {
        accessoryX += 3.0;
        self.protectedBadge.frame = CGRectMake(accessoryX, headerY + floor((headerHeight - 12.0) * 0.5), 12.0, 12.0);
        accessoryX += 12.0;
    } else {
        self.protectedBadge.frame = CGRectZero;
    }
    self.metaLabel.frame = CGRectMake(accessoryX + 4.0, headerY, metaW, headerHeight);

    CGFloat cy = headerY + headerHeight;
    if (self.bodyLabel.text.length) {
        cy += 2.0;
        CGFloat bodyH = SX278TextHeight(self.bodyLabel.text, cw);
        self.bodyLabel.frame = CGRectMake(x, cy, cw, bodyH);
        cy += bodyH;
    } else {
        self.bodyLabel.frame = CGRectZero;
    }

    CGSize mediaSize = SX278MediaSize(self.post, MAX(1.0, cw - 4.0), MAX(1.0, w - 4.0));
    CGFloat mh = mediaSize.height;
    CGFloat mediaWidth = mediaSize.width;
    if (mh > 0.0 && mediaWidth > 0.0) {
        cy += 6.0;
        self.mediaContainer.frame = CGRectMake(x, cy, mediaWidth, mh);
        cy += mh;
        NSUInteger count = 0;
        for (SX278MediaTile *tile in self.tiles) if (!tile.hidden) count++;
        CGFloat gap = 2.0;
        if (count == 1) {
            self.mediaContainer.scrollEnabled = NO;
            self.mediaContainer.contentSize = self.mediaContainer.bounds.size;
            self.tiles[0].layer.cornerRadius = 0.0;
            self.tiles[0].frame = self.mediaContainer.bounds;
        } else {
            self.mediaContainer.scrollEnabled = YES;
            CGFloat maxItemWidth = mediaWidth * 0.8;
            CGFloat offsetX = 0.0;
            NSArray *media = [self.post[@"media"] isKindOfClass:NSArray.class] ? self.post[@"media"] : @[];
            for (NSUInteger i = 0; i < count; i++) {
                NSDictionary *item = (i < media.count && [media[i] isKindOfClass:NSDictionary.class]) ? media[i] : @{};
                CGFloat sourceW = [item[@"width"] respondsToSelector:@selector(doubleValue)] ? [item[@"width"] doubleValue] : 0.0;
                CGFloat sourceH = [item[@"height"] respondsToSelector:@selector(doubleValue)] ? [item[@"height"] doubleValue] : 0.0;
                CGFloat aspect = (sourceW > 0.0 && sourceH > 0.0) ? (sourceW / sourceH) : 1.0;
                CGFloat itemWidth = MIN(round(mh * aspect), maxItemWidth);
                if (itemWidth <= 0.0) itemWidth = MIN(mh, maxItemWidth);
                SX278MediaTile *tile = self.tiles[i];
                tile.layer.cornerRadius = 12.0;
                tile.clipsToBounds = YES;
                tile.frame = CGRectMake(offsetX, 0.0, itemWidth, mh);
                offsetX += itemWidth + gap;
            }
            self.mediaContainer.contentSize = CGSizeMake(MAX(mediaWidth, offsetX > 0.0 ? offsetX - gap : 0.0), mh);
        }
    } else {
        self.mediaContainer.frame = CGRectZero;
    }

    cy += 4.0;
    CGFloat itemWidths[6];
    CGFloat total = 0.0;
    for (NSUInteger i = 0; i < 6; i++) {
        NSString *text = self.actionLabels[i].text ?: @"";
        CGFloat labelW = text.length ? ceil([self.actionLabels[i] sizeThatFits:CGSizeMake(CGFLOAT_MAX, 23.0)].width) : 0.0;
        itemWidths[i] = 16.0 + (labelW > 0.0 ? 5.0 + labelW : 0.0);
        total += itemWidths[i];
    }
    CGFloat gap = MAX(0.0, (cw - total) / 5.0);
    CGFloat ax = x;
    for (NSUInteger i = 0; i < 6; i++) {
        NSString *text = self.actionLabels[i].text ?: @"";
        CGFloat labelW = text.length ? MAX(0.0, itemWidths[i] - 21.0) : 0.0;
        self.actionIcons[i].frame = CGRectMake(ax, cy + 5.5, 16.0, 16.0);
        self.actionLabels[i].frame = labelW > 0.0 ? CGRectMake(ax + 21.0, cy + 2.0, labelW, 23.0) : CGRectZero;
        ax += itemWidths[i] + gap;
    }

    self.separator.frame = CGRectMake(0.0, CGRectGetHeight(self.contentView.bounds) - 0.5, w, 0.5);
}
@end

@interface SX278TimelineAdapter : NSObject <UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching>
@property(nonatomic,weak) NativeProfileViewController *profile;
@end
@implementation SX278TimelineAdapter
- (NSInteger)selectedTab {
    @try { return [[self.profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *e) { return -1; }
}
- (NSDictionary *)data { return [self.profile.profileData isKindOfClass:NSDictionary.class] ? self.profile.profileData : @{}; }
- (NSArray *)itemsForTab:(NSInteger)tab { return SX278ItemsForTab([self data], tab); }
- (BOOL)hasMore:(NSInteger)tab items:(NSArray *)items {
    if (tab < 0 || tab > 3) return NO;
    NSArray *keys = @[@"postsHasMore", @"repliesHasMore", @"repostsHasMore", @"mediaHasMore"];
    id value = [self data][keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : (items.count > 0);
}
- (BOOL)moreLoading:(NSInteger)tab {
    if (tab < 0 || tab > 3) return NO;
    NSArray *keys = @[@"postsMoreLoading", @"repliesMoreLoading", @"repostsMoreLoading", @"mediaMoreLoading"];
    id value = [self data][keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}
- (BOOL)initialLoading:(NSInteger)tab {
    if (tab < 0 || tab > 3) return NO;
    NSArray *keys = @[@"postsLoading", @"repliesLoading", @"repostsLoading", @"mediaLoading"];
    id value = [self data][keys[(NSUInteger)tab]];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}
- (void)requestMoreIfNeededForRow:(NSInteger)row {
    NSInteger tab = [self selectedTab];
    if (tab < 0 || tab > 3) return;
    NSArray *items = [self itemsForTab:tab];
    if (items.count == 0 || [self initialLoading:tab] || row < (NSInteger)items.count - 20 || ![self hasMore:tab items:items] || [self moreLoading:tab]) return;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSNumber *last = objc_getAssociatedObject(self.profile, &SX278LastRequestKey);
    if (last && now - last.doubleValue < 1.0) return;
    objc_setAssociatedObject(self.profile, &SX278LastRequestKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.profile sx238_loadMoreTimeline:nil];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger tab = [self selectedTab];
    NSArray *items = [self itemsForTab:tab];
    return items.count ? (NSInteger)items.count : 1;
}
- (UITableViewCell *)stateCell:(UITableView *)table text:(NSString *)text {
    static NSString *rid = @"SX278State";
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:rid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;
    cell.textLabel.text = text;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = UIColor.secondaryLabelColor;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.numberOfLines = 0;
    return cell;
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger tab = [self selectedTab];
    NSArray *items = [self itemsForTab:tab];
    if (items.count == 0) {
        NSArray *loading = @[@"Xからポストを読み込み中…", @"Xから返信を読み込み中…", @"Xからリポストを読み込み中…", @"Xからメディアを読み込み中…"];
        NSArray *empty = @[@"通常ポストはありません", @"返信はありません", @"リポストはありません", @"メディアはありません"];
        return [self stateCell:table text:[self initialLoading:tab] ? loading[(NSUInteger)tab] : empty[(NSUInteger)tab]];
    }
    static NSString *rid = @"SX278Post";
    SX278PostCell *cell = [table dequeueReusableCellWithIdentifier:rid];
    if (!cell) cell = [[SX278PostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    [cell configureWithPost:items[(NSUInteger)ip.row] profile:self.profile];
    [self requestMoreIfNeededForRow:ip.row];
    return cell;
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger tab = [self selectedTab];
    NSArray *items = [self itemsForTab:tab];
    if (tab < 0 || tab > 3 || items.count == 0 || (NSUInteger)ip.row >= items.count) return 80.0;
    return SX278PostHeight(items[(NSUInteger)ip.row], CGRectGetWidth(table.bounds));
}
- (void)tableView:(UITableView *)table prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSInteger maxRow = -1;
    for (NSIndexPath *path in paths) maxRow = MAX(maxRow, path.row);
    if (maxRow >= 0) [self requestMoreIfNeededForRow:maxRow];
}
@end

static UIStackView *SX278FindPostsStack(UIView *content) {
    for (UIView *view in content.subviews) {
        if ([view isKindOfClass:UIStackView.class] && ((UIStackView *)view).axis == UILayoutConstraintAxisVertical) return (UIStackView *)view;
    }
    return nil;
}

static CGFloat SX278HeaderHeight(UIView *header, CGFloat width) {
    if (!header) return 0.0;
    CGRect frame = header.frame;
    frame.size.width = MAX(1.0, width);
    frame.size.height = MAX(1.0, frame.size.height);
    header.frame = frame;
    [header setNeedsLayout];
    [header layoutIfNeeded];
    CGFloat maxY = 0.0;
    for (UIView *view in header.subviews) if (!view.hidden) maxY = MAX(maxY, CGRectGetMaxY(view.frame));
    return ceil(MAX(1.0, maxY));
}

static void SX278ResizeHeader(NativeProfileViewController *profile) {
    UITableView *table = objc_getAssociatedObject(profile, &SX278TableKey);
    UIView *header = table.tableHeaderView;
    if (!table || !header) return;
    CGFloat width = CGRectGetWidth(table.bounds);
    if (width <= 0.0) return;
    CGFloat height = SX278HeaderHeight(header, width);
    if (fabs(header.frame.size.width - width) < 0.5 && fabs(header.frame.size.height - height) < 0.5) return;
    CGRect frame = header.frame;
    frame.size = CGSizeMake(width, height);
    header.frame = frame;
    table.tableHeaderView = header;
}

static void SX278Reload(NativeProfileViewController *profile) {
    UITableView *table = objc_getAssociatedObject(profile, &SX278TableKey);
    if (!table) return;
    [table reloadData];
    SX278ResizeHeader(profile);
}

static void SX278Install(NativeProfileViewController *profile) {
    if (!profile.isViewLoaded || objc_getAssociatedObject(profile, &SX278TableKey)) return;
    UIScrollView *old = nil;
    UIView *content = nil;
    @try { old = [profile valueForKey:@"scrollView"]; content = [profile valueForKey:@"contentView"]; }
    @catch (__unused NSException *e) {}
    if (![old isKindOfClass:UIScrollView.class] || !content) return;
    [profile.view layoutIfNeeded];

    UIStackView *posts = SX278FindPostsStack(content);
    if (posts) {
        NSMutableArray *remove = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in [content.constraints copy]) {
            if (constraint.firstItem == posts || constraint.secondItem == posts) [remove addObject:constraint];
        }
        [NSLayoutConstraint deactivateConstraints:remove];
        [posts removeFromSuperview];
    }

    CGFloat width = CGRectGetWidth(profile.view.bounds);
    CGFloat headerHeight = SX278HeaderHeight(content, width);
    [content removeFromSuperview];
    content.translatesAutoresizingMaskIntoConstraints = YES;
    content.frame = CGRectMake(0, 0, width, headerHeight);
    [old removeFromSuperview];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.backgroundColor = UIColor.systemBackgroundColor;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.alwaysBounceVertical = YES;
    table.estimatedRowHeight = 0.0;
    if (@available(iOS 11.0, *)) table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    SX278TimelineAdapter *adapter = [SX278TimelineAdapter new];
    adapter.profile = profile;
    table.dataSource = adapter;
    table.delegate = adapter;
    table.prefetchDataSource = adapter;
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

    objc_setAssociatedObject(profile, &SX278TableKey, table, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(profile, &SX278AdapterKey, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try { [profile setValue:table forKey:@"scrollView"]; }
    @catch (__unused NSException *e) {}
    [table reloadData];
    SX278ResizeHeader(profile);
}

static NSInteger SX278SelectedTab(NativeProfileViewController *profile) {
    @try { return [[profile valueForKey:@"selectedProfileTab"] integerValue]; }
    @catch (__unused NSException *e) { return -1; }
}

static void SX278ViewDidLoad(id obj, SEL cmd) {
    if (SX278PreviousViewDidLoadIMP) SX278PreviousViewDidLoadIMP(obj, cmd);
    SX278Install((NativeProfileViewController *)obj);
}

static void SX278ViewDidLayout(id obj, SEL cmd) {
    if (SX278PreviousViewDidLayoutIMP) SX278PreviousViewDidLayoutIMP(obj, cmd);
    SX278ResizeHeader((NativeProfileViewController *)obj);
}

static void SX278SetProfileData(id obj, SEL cmd, NSDictionary *data) {
    NativeProfileViewController *profile = (NativeProfileViewController *)obj;
    NSDictionary *oldData = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSInteger oldTab = SX278SelectedTab(profile);
    NSArray *oldItems = [SX278ItemsForTab(oldData, oldTab) copy];

    if (SX278PreviousSetProfileDataIMP) SX278PreviousSetProfileDataIMP(obj, cmd, data);

    NSInteger newTab = SX278SelectedTab(profile);
    NSDictionary *newData = [profile.profileData isKindOfClass:NSDictionary.class] ? profile.profileData : @{};
    NSArray *newItems = [SX278ItemsForTab(newData, newTab) copy];
    __weak NativeProfileViewController *weak = profile;
    dispatch_async(dispatch_get_main_queue(), ^{
        NativeProfileViewController *strong = weak;
        if (!strong) return;
        UITableView *table = objc_getAssociatedObject(strong, &SX278TableKey);
        if (!table) return;

        if (oldTab == newTab && oldTab >= 0 && oldTab <= 3 && oldItems.count > 0 && newItems.count > oldItems.count && SX278SamePrefix(oldItems, newItems)) {
            NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
            for (NSUInteger idx = oldItems.count; idx < newItems.count; idx++) {
                [paths addObject:[NSIndexPath indexPathForRow:(NSInteger)idx inSection:0]];
            }
            [table insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            SX278ResizeHeader(strong);
            return;
        }

        if (oldTab == newTab && oldItems.count == newItems.count && [oldItems isEqual:newItems]) {
            SX278ResizeHeader(strong);
            return;
        }

        SX278Reload(strong);
    });
}

@interface SX278Installer : NSObject @end
@implementation SX278Installer
+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"NativeProfileViewController");
        if (!cls) return;
        Method viewDidLoadMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (viewDidLoadMethod) {
            SX278PreviousViewDidLoadIMP = (SX278ViewDidLoadIMP)method_getImplementation(viewDidLoadMethod);
            class_replaceMethod(cls, @selector(viewDidLoad), (IMP)SX278ViewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
        }
        Method layoutMethod = class_getInstanceMethod(cls, @selector(viewDidLayoutSubviews));
        if (layoutMethod) {
            SX278PreviousViewDidLayoutIMP = (SX278ViewDidLayoutIMP)method_getImplementation(layoutMethod);
            class_replaceMethod(cls, @selector(viewDidLayoutSubviews), (IMP)SX278ViewDidLayout, method_getTypeEncoding(layoutMethod));
        }
        SEL setter = NSSelectorFromString(@"setProfileData:");
        Method setterMethod = class_getInstanceMethod(cls, setter);
        if (setterMethod) {
            SX278PreviousSetProfileDataIMP = (SX278SetProfileDataIMP)method_getImplementation(setterMethod);
            class_replaceMethod(cls, setter, (IMP)SX278SetProfileData, method_getTypeEncoding(setterMethod));
        }
    });
}
@end
