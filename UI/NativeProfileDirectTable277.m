#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AVKit/AVKit.h>

static char SX277AdapterKey;
static char SX277TableKey;
static char SX277LastRequestKey;

typedef void (*SX277SetProfileDataIMP)(id, SEL, NSDictionary *);
static SX277SetProfileDataIMP SX277PreviousSetProfileDataIMP = NULL;
typedef void (*SX277ViewDidLoadIMP)(id, SEL);
static SX277ViewDidLoadIMP SX277PreviousViewDidLoadIMP = NULL;
typedef void (*SX277ViewDidLayoutIMP)(id, SEL);
static SX277ViewDidLayoutIMP SX277PreviousViewDidLayoutIMP = NULL;

@interface NativeProfileViewController (SX277Private)
- (NSString *)stringValue:(id)value;
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
- (void)profileTabSwiped:(UISwipeGestureRecognizer *)gesture;
- (void)sx238_loadMoreTimeline:(UIButton *)sender;
@end

static NSString *SX277String(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    return @"";
}

static NSString *SX277Date(NSString *raw) {
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
    return date ? [output stringFromDate:date] : @"";
}

static CGFloat SX277MediaHeight(NSDictionary *post) {
    NSArray *media = [post[@"media"] isKindOfClass:NSArray.class] ? post[@"media"] : @[];
    if (media.count == 0 && SX277String(post[@"mediaURL"]).length) return 220.0;
    NSUInteger count = MIN(media.count, (NSUInteger)4);
    if (count == 0) return 0.0;
    if (count <= 2) return 220.0;
    if (count == 3) return 240.0;
    return 260.0;
}

static CGFloat SX277PostHeight(NSDictionary *post, CGFloat width) {
    CGFloat h = 0.5; // separator
    BOOL repost = [post[@"isRepost"] respondsToSelector:@selector(boolValue)] && [post[@"isRepost"] boolValue];
    if (repost) h += 30.0;

    CGFloat contentWidth = MAX(80.0, width - 12.0 - 40.0 - 12.0 - 12.0);
    CGFloat row = 11.0 + 20.0; // top + header
    NSString *text = SX277String(post[@"text"]);
    if (text.length) {
        CGRect rect = [text boundingRectWithSize:CGSizeMake(contentWidth, CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading
                                     attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15]}
                                        context:nil];
        row += 5.0 + ceil(rect.size.height);
    }
    CGFloat mediaH = SX277MediaHeight(post);
    if (mediaH > 0) row += 9.0 + mediaH;
    row += 5.0 + 28.0 + 8.0; // actions + bottom
    h += MAX(59.0, row);
    return ceil(h);
}

@interface SX277MediaTile : UIControl
@property(nonatomic,strong) UIImageView *imageView;
@property(nonatomic,strong) UIImageView *playView;
@property(nonatomic,copy) NSString *videoURL;
@end
@implementation SX277MediaTile
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.clipsToBounds = YES;
        self.backgroundColor = UIColor.secondarySystemBackgroundColor;
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
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
- (void)layoutSubviews { [super layoutSubviews]; self.imageView.frame=self.bounds; self.playView.frame=CGRectMake((self.bounds.size.width-44)/2.0,(self.bounds.size.height-44)/2.0,44,44); }
@end

@interface SX277PostCell : UITableViewCell
@property(nonatomic,weak) NativeProfileViewController *profile;
@property(nonatomic,strong) UILabel *repostLabel;
@property(nonatomic,strong) UIImageView *avatar;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *metaLabel;
@property(nonatomic,strong) UILabel *bodyLabel;
@property(nonatomic,strong) UIView *mediaContainer;
@property(nonatomic,strong) NSArray<SX277MediaTile *> *tiles;
@property(nonatomic,strong) NSArray<UIImageView *> *actionIcons;
@property(nonatomic,strong) NSArray<UILabel *> *actionLabels;
@property(nonatomic,strong) UIView *separator;
@property(nonatomic,strong) NSDictionary *post;
@end

@implementation SX277PostCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.systemBackgroundColor;
        self.contentView.backgroundColor = UIColor.systemBackgroundColor;

        _repostLabel=[UILabel new]; _repostLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]; _repostLabel.textColor=UIColor.secondaryLabelColor; [self.contentView addSubview:_repostLabel];
        _avatar=[UIImageView new]; _avatar.backgroundColor=UIColor.secondarySystemBackgroundColor; _avatar.contentMode=UIViewContentModeScaleAspectFill; _avatar.clipsToBounds=YES; _avatar.layer.cornerRadius=20; [self.contentView addSubview:_avatar];
        _nameLabel=[UILabel new]; _nameLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; _nameLabel.lineBreakMode=NSLineBreakByTruncatingTail; [self.contentView addSubview:_nameLabel];
        _metaLabel=[UILabel new]; _metaLabel.font=[UIFont systemFontOfSize:15]; _metaLabel.textColor=UIColor.secondaryLabelColor; _metaLabel.lineBreakMode=NSLineBreakByTruncatingTail; [self.contentView addSubview:_metaLabel];
        _bodyLabel=[UILabel new]; _bodyLabel.font=[UIFont systemFontOfSize:15]; _bodyLabel.numberOfLines=0; _bodyLabel.lineBreakMode=NSLineBreakByWordWrapping; [self.contentView addSubview:_bodyLabel];
        _mediaContainer=[UIView new]; _mediaContainer.clipsToBounds=YES; _mediaContainer.layer.cornerRadius=12; [self.contentView addSubview:_mediaContainer];
        NSMutableArray *tiles=[NSMutableArray array];
        for(int i=0;i<4;i++){ SX277MediaTile *tile=[SX277MediaTile new]; tile.hidden=YES; [tile addTarget:self action:@selector(mediaTapped:) forControlEvents:UIControlEventTouchUpInside]; [_mediaContainer addSubview:tile]; [tiles addObject:tile]; }
        _tiles=tiles;

        NSArray *symbols=@[@"bubble",@"arrow.2.squarepath",@"heart",@"chart.bar",@"bookmark",@"square.and.arrow.up"];
        NSMutableArray *icons=[NSMutableArray array], *labels=[NSMutableArray array];
        for(NSString *symbol in symbols){ UIImageView *iv=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]]; iv.tintColor=UIColor.secondaryLabelColor; iv.contentMode=UIViewContentModeScaleAspectFit; [self.contentView addSubview:iv]; [icons addObject:iv]; UILabel *l=[UILabel new]; l.font=[UIFont systemFontOfSize:12]; l.textColor=UIColor.secondaryLabelColor; [self.contentView addSubview:l]; [labels addObject:l]; }
        _actionIcons=icons; _actionLabels=labels;
        _separator=[UIView new]; _separator.backgroundColor=UIColor.separatorColor; [self.contentView addSubview:_separator];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatar.image=[UIImage systemImageNamed:@"person.crop.circle.fill"];
    for(SX277MediaTile *tile in self.tiles){ tile.imageView.image=nil; tile.videoURL=nil; tile.playView.hidden=YES; tile.hidden=YES; }
}

- (void)configureWithPost:(NSDictionary *)post profile:(NativeProfileViewController *)profile {
    self.post=post; self.profile=profile;
    NSDictionary *pd=[profile.profileData isKindOfClass:NSDictionary.class]?profile.profileData:@{};
    NSString *name=SX277String(post[@"authorName"]); if(!name.length) name=SX277String(pd[@"name"]);
    NSString *handle=SX277String(post[@"authorHandle"]); if(!handle.length) handle=SX277String(pd[@"handle"]); if(handle.length && ![handle hasPrefix:@"@"]) handle=[@"@" stringByAppendingString:handle];
    NSString *avatarURL=SX277String(post[@"authorAvatarURL"]); if(!avatarURL.length) avatarURL=SX277String(pd[@"avatarURL"]);
    self.nameLabel.text=name;
    NSString *date=SX277Date(SX277String(post[@"createdAt"]));
    self.metaLabel.text=(handle.length&&date.length)?[NSString stringWithFormat:@"%@ · %@",handle,date]:(handle.length?handle:date);
    self.bodyLabel.text=SX277String(post[@"text"]);
    BOOL repost=[post[@"isRepost"] respondsToSelector:@selector(boolValue)]&&[post[@"isRepost"] boolValue];
    NSString *profileName=SX277String(pd[@"name"]);
    self.repostLabel.hidden=!repost;
    self.repostLabel.text=repost?(profileName.length?[NSString stringWithFormat:@"↻  %@さんがリポスト",profileName]:@"↻  リポスト"):@"";
    self.avatar.image=[UIImage systemImageNamed:@"person.crop.circle.fill"];
    if(avatarURL.length) [profile loadImageURLString:avatarURL into:self.avatar];

    NSArray *media=[post[@"media"] isKindOfClass:NSArray.class]?post[@"media"]:@[];
    if(media.count==0){ NSString *legacy=SX277String(post[@"mediaURL"]); if(legacy.length) media=@[@{@"type":@"photo",@"previewURL":legacy}]; }
    NSUInteger count=MIN(media.count,(NSUInteger)4);
    self.mediaContainer.hidden=(count==0);
    for(NSUInteger i=0;i<4;i++){
        SX277MediaTile *tile=self.tiles[i];
        tile.hidden=(i>=count); tile.imageView.image=nil; tile.videoURL=nil; tile.playView.hidden=YES;
        if(i<count){ NSDictionary *m=[media[i] isKindOfClass:NSDictionary.class]?media[i]:@{}; NSString *preview=SX277String(m[@"previewURL"]); if(preview.length)[profile loadImageURLString:preview into:tile.imageView]; NSString *type=SX277String(m[@"type"]); NSString *video=SX277String(m[@"videoURL"]); BOOL playable=([type isEqualToString:@"video"]||[type isEqualToString:@"animated_gif"])&&video.length; tile.videoURL=playable?video:nil; tile.playView.hidden=!playable; }
    }

    NSArray *counts=@[post[@"replyCount"]?:@0,post[@"retweetCount"]?:@0,post[@"favoriteCount"]?:@0,@0,@0,@0];
    for(NSUInteger i=0;i<6;i++){ NSInteger v=[counts[i] respondsToSelector:@selector(integerValue)]?[counts[i] integerValue]:0; self.actionLabels[i].text=v>0?[NSString stringWithFormat:@"%ld",(long)v]:@""; }
    [self setNeedsLayout];
}

- (void)mediaTapped:(SX277MediaTile *)sender {
    if(sender.videoURL.length==0||!self.profile)return;
    NSURL *url=[NSURL URLWithString:sender.videoURL]; if(!url)return;
    AVPlayer *player=[AVPlayer playerWithURL:url]; AVPlayerViewController *vc=[AVPlayerViewController new]; vc.player=player; vc.modalPresentationStyle=UIModalPresentationFullScreen; [self.profile presentViewController:vc animated:YES completion:^{[player play];}];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w=CGRectGetWidth(self.contentView.bounds); BOOL repost=!self.repostLabel.hidden; CGFloat y=0;
    if(repost){ self.repostLabel.frame=CGRectMake(64,7,MAX(0,w-76),18); y=30; } else self.repostLabel.frame=CGRectZero;
    self.avatar.frame=CGRectMake(12,y+11,40,40);
    CGFloat x=64, cw=MAX(80,w-x-12);
    self.nameLabel.frame=CGRectMake(x,y+10,cw*0.42,21);
    self.metaLabel.frame=CGRectMake(CGRectGetMaxX(self.nameLabel.frame)+4,y+10,MAX(0,cw-cw*0.42-4),21);
    CGFloat cy=y+36;
    if(self.bodyLabel.text.length){ CGSize s=[self.bodyLabel sizeThatFits:CGSizeMake(cw,CGFLOAT_MAX)]; self.bodyLabel.frame=CGRectMake(x,cy,cw,ceil(s.height)); cy=CGRectGetMaxY(self.bodyLabel.frame)+9; } else self.bodyLabel.frame=CGRectZero;
    CGFloat mh=SX277MediaHeight(self.post);
    if(mh>0){ self.mediaContainer.frame=CGRectMake(x,cy,cw,mh); cy+=mh+5; NSUInteger count=0; for(SX277MediaTile *t in self.tiles)if(!t.hidden)count++; CGFloat gap=2;
        if(count==1){ self.tiles[0].frame=self.mediaContainer.bounds; }
        else if(count==2){ CGFloat half=(cw-gap)/2; self.tiles[0].frame=CGRectMake(0,0,half,mh); self.tiles[1].frame=CGRectMake(half+gap,0,half,mh); }
        else if(count==3){ CGFloat half=(cw-gap)/2, halfH=(mh-gap)/2; self.tiles[0].frame=CGRectMake(0,0,half,mh); self.tiles[1].frame=CGRectMake(half+gap,0,half,halfH); self.tiles[2].frame=CGRectMake(half+gap,halfH+gap,half,halfH); }
        else if(count>=4){ CGFloat half=(cw-gap)/2, halfH=(mh-gap)/2; for(NSUInteger i=0;i<4;i++)self.tiles[i].frame=CGRectMake((i%2)*(half+gap),(i/2)*(halfH+gap),half,halfH); }
    } else self.mediaContainer.frame=CGRectZero;
    CGFloat actionY=cy; CGFloat slot=cw/6.0;
    for(NSUInteger i=0;i<6;i++){ CGFloat sx=x+i*slot; self.actionIcons[i].frame=CGRectMake(sx,actionY+5,17,17); self.actionLabels[i].frame=CGRectMake(sx+22,actionY+2,MAX(0,slot-22),23); }
    self.separator.frame=CGRectMake(0,CGRectGetHeight(self.contentView.bounds)-0.5,w,0.5);
}
@end

@interface SX277TimelineAdapter : NSObject <UITableViewDataSource,UITableViewDelegate,UITableViewDataSourcePrefetching>
@property(nonatomic,weak) NativeProfileViewController *profile;
@end
@implementation SX277TimelineAdapter
- (NSInteger)selectedTab { @try{return [[self.profile valueForKey:@"selectedProfileTab"] integerValue];}@catch(__unused NSException *e){return -1;} }
- (NSDictionary *)data { return [self.profile.profileData isKindOfClass:NSDictionary.class]?self.profile.profileData:@{}; }
- (NSArray *)itemsForTab:(NSInteger)tab { if(tab<0||tab>2)return @[]; NSArray *keys=@[@"posts",@"replies",@"reposts"]; id v=[self data][keys[(NSUInteger)tab]]; return [v isKindOfClass:NSArray.class]?v:@[]; }
- (BOOL)hasMore:(NSInteger)tab items:(NSArray *)items { if(tab<0||tab>2)return NO; NSArray *keys=@[@"postsHasMore",@"repliesHasMore",@"repostsHasMore"]; id v=[self data][keys[(NSUInteger)tab]]; return [v respondsToSelector:@selector(boolValue)]?[v boolValue]:(items.count>0); }
- (BOOL)moreLoading:(NSInteger)tab { if(tab<0||tab>2)return NO; NSArray *keys=@[@"postsMoreLoading",@"repliesMoreLoading",@"repostsMoreLoading"]; id v=[self data][keys[(NSUInteger)tab]]; return [v respondsToSelector:@selector(boolValue)]?[v boolValue]:NO; }
- (BOOL)initialLoading:(NSInteger)tab { if(tab<0||tab>2)return NO; NSArray *keys=@[@"postsLoading",@"repliesLoading",@"repostsLoading"]; id v=[self data][keys[(NSUInteger)tab]]; return [v respondsToSelector:@selector(boolValue)]?[v boolValue]:NO; }
- (void)requestMoreIfNeededForRow:(NSInteger)row { NSInteger tab=[self selectedTab]; if(tab<0||tab>2)return; NSArray *items=[self itemsForTab:tab]; if(items.count==0||row<(NSInteger)items.count-8||![self hasMore:tab items:items]||[self moreLoading:tab])return; NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate]; NSNumber *last=objc_getAssociatedObject(self.profile,&SX277LastRequestKey); if(last&&now-last.doubleValue<1.0)return; objc_setAssociatedObject(self.profile,&SX277LastRequestKey,@(now),OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self.profile sx238_loadMoreTimeline:nil]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { NSInteger tab=[self selectedTab]; if(tab==3)return 1; NSArray *items=[self itemsForTab:tab]; return items.count?items.count:1; }
- (UITableViewCell *)stateCell:(UITableView *)table text:(NSString *)text { static NSString *rid=@"SX277State"; UITableViewCell *c=[table dequeueReusableCellWithIdentifier:rid]; if(!c)c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid]; c.selectionStyle=UITableViewCellSelectionStyleNone; c.backgroundColor=UIColor.systemBackgroundColor; c.textLabel.text=text; c.textLabel.textAlignment=NSTextAlignmentCenter; c.textLabel.textColor=UIColor.secondaryLabelColor; c.textLabel.font=[UIFont systemFontOfSize:14]; c.textLabel.numberOfLines=0; return c; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)ip { NSInteger tab=[self selectedTab]; if(tab==3)return [self stateCell:table text:@"メディアはまだ接続していません"]; NSArray *items=[self itemsForTab:tab]; if(items.count==0){ NSArray *loading=@[@"Xからポストを読み込み中…",@"Xから返信を読み込み中…",@"Xからリポストを読み込み中…"]; NSArray *empty=@[@"通常ポストはありません",@"返信はありません",@"リポストはありません"]; return [self stateCell:table text:[self initialLoading:tab]?loading[(NSUInteger)tab]:empty[(NSUInteger)tab]]; } static NSString *rid=@"SX277Post"; SX277PostCell *cell=[table dequeueReusableCellWithIdentifier:rid]; if(!cell)cell=[[SX277PostCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid]; [cell configureWithPost:items[(NSUInteger)ip.row] profile:self.profile]; [self requestMoreIfNeededForRow:ip.row]; return cell; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)ip { NSInteger tab=[self selectedTab]; NSArray *items=[self itemsForTab:tab]; if(tab<0||tab>2||items.count==0||(NSUInteger)ip.row>=items.count)return 80; return SX277PostHeight(items[(NSUInteger)ip.row],CGRectGetWidth(table.bounds)); }
- (void)tableView:(UITableView *)table prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)paths { NSInteger max=-1; for(NSIndexPath *p in paths)max=MAX(max,p.row); if(max>=0)[self requestMoreIfNeededForRow:max]; }
@end

static UIStackView *SX277FindPostsStack(UIView *content){ for(UIView *v in content.subviews)if([v isKindOfClass:UIStackView.class]&&((UIStackView*)v).axis==UILayoutConstraintAxisVertical)return (UIStackView*)v; return nil; }
static CGFloat SX277HeaderHeight(UIView *header,CGFloat width){ if(!header)return 0; CGRect f=header.frame; f.size.width=MAX(1,width); f.size.height=MAX(1,f.size.height); header.frame=f; [header setNeedsLayout]; [header layoutIfNeeded]; CGFloat maxY=0; for(UIView *v in header.subviews)if(!v.hidden)maxY=MAX(maxY,CGRectGetMaxY(v.frame)); return ceil(MAX(1,maxY)); }
static void SX277ResizeHeader(NativeProfileViewController *profile){ UITableView *table=objc_getAssociatedObject(profile,&SX277TableKey); UIView *header=table.tableHeaderView; if(!table||!header)return; CGFloat w=CGRectGetWidth(table.bounds); if(w<=0)return; CGFloat h=SX277HeaderHeight(header,w); if(fabs(header.frame.size.width-w)<0.5&&fabs(header.frame.size.height-h)<0.5)return; CGRect f=header.frame; f.size=CGSizeMake(w,h); header.frame=f; table.tableHeaderView=header; }
static void SX277Reload(NativeProfileViewController *profile){ UITableView *table=objc_getAssociatedObject(profile,&SX277TableKey); if(!table)return; [table reloadData]; SX277ResizeHeader(profile); }
static void SX277Install(NativeProfileViewController *profile){ if(!profile.isViewLoaded||objc_getAssociatedObject(profile,&SX277TableKey))return; UIScrollView *old=nil; UIView *content=nil; @try{old=[profile valueForKey:@"scrollView"];content=[profile valueForKey:@"contentView"];}@catch(__unused NSException *e){} if(![old isKindOfClass:UIScrollView.class]||!content)return; [profile.view layoutIfNeeded]; UIStackView *posts=SX277FindPostsStack(content); if(posts){ NSMutableArray *rm=[NSMutableArray array]; for(NSLayoutConstraint *c in [content.constraints copy])if(c.firstItem==posts||c.secondItem==posts)[rm addObject:c]; [NSLayoutConstraint deactivateConstraints:rm]; [posts removeFromSuperview]; } CGFloat w=CGRectGetWidth(profile.view.bounds), hh=SX277HeaderHeight(content,w); [content removeFromSuperview]; content.translatesAutoresizingMaskIntoConstraints=YES; content.frame=CGRectMake(0,0,w,hh); [old removeFromSuperview]; UITableView *table=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain]; table.translatesAutoresizingMaskIntoConstraints=NO; table.backgroundColor=UIColor.systemBackgroundColor; table.separatorStyle=UITableViewCellSeparatorStyleNone; table.alwaysBounceVertical=YES; table.estimatedRowHeight=0; if(@available(iOS 11.0,*))table.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever; SX277TimelineAdapter *adapter=[SX277TimelineAdapter new]; adapter.profile=profile; table.dataSource=adapter; table.delegate=adapter; table.prefetchDataSource=adapter; table.tableHeaderView=content; [profile.view insertSubview:table atIndex:0]; [NSLayoutConstraint activateConstraints:@[[table.topAnchor constraintEqualToAnchor:profile.view.topAnchor],[table.leadingAnchor constraintEqualToAnchor:profile.view.leadingAnchor],[table.trailingAnchor constraintEqualToAnchor:profile.view.trailingAnchor],[table.bottomAnchor constraintEqualToAnchor:profile.view.bottomAnchor]]]; UISwipeGestureRecognizer *left=[[UISwipeGestureRecognizer alloc]initWithTarget:profile action:@selector(profileTabSwiped:)]; left.direction=UISwipeGestureRecognizerDirectionLeft; [table addGestureRecognizer:left]; UISwipeGestureRecognizer *right=[[UISwipeGestureRecognizer alloc]initWithTarget:profile action:@selector(profileTabSwiped:)]; right.direction=UISwipeGestureRecognizerDirectionRight; [table addGestureRecognizer:right]; objc_setAssociatedObject(profile,&SX277TableKey,table,OBJC_ASSOCIATION_RETAIN_NONATOMIC); objc_setAssociatedObject(profile,&SX277AdapterKey,adapter,OBJC_ASSOCIATION_RETAIN_NONATOMIC); @try{[profile setValue:table forKey:@"scrollView"];}@catch(__unused NSException *e){} [table reloadData]; SX277ResizeHeader(profile); }
static void SX277ViewDidLoad(id obj,SEL cmd){ if(SX277PreviousViewDidLoadIMP)SX277PreviousViewDidLoadIMP(obj,cmd); SX277Install((NativeProfileViewController*)obj); }
static void SX277ViewDidLayout(id obj,SEL cmd){ if(SX277PreviousViewDidLayoutIMP)SX277PreviousViewDidLayoutIMP(obj,cmd); SX277ResizeHeader((NativeProfileViewController*)obj); }
static void SX277SetProfileData(id obj,SEL cmd,NSDictionary *data){ if(SX277PreviousSetProfileDataIMP)SX277PreviousSetProfileDataIMP(obj,cmd,data); __weak NativeProfileViewController *weak=(NativeProfileViewController*)obj; dispatch_async(dispatch_get_main_queue(),^{ if(weak)SX277Reload(weak); }); }

@interface SX277Installer:NSObject @end
@implementation SX277Installer
+ (void)load { dispatch_async(dispatch_get_main_queue(),^{ Class cls=NSClassFromString(@"NativeProfileViewController"); if(!cls)return; Method m=class_getInstanceMethod(cls,@selector(viewDidLoad)); if(m){SX277PreviousViewDidLoadIMP=(SX277ViewDidLoadIMP)method_getImplementation(m); class_replaceMethod(cls,@selector(viewDidLoad),(IMP)SX277ViewDidLoad,method_getTypeEncoding(m));} Method l=class_getInstanceMethod(cls,@selector(viewDidLayoutSubviews)); if(l){SX277PreviousViewDidLayoutIMP=(SX277ViewDidLayoutIMP)method_getImplementation(l); class_replaceMethod(cls,@selector(viewDidLayoutSubviews),(IMP)SX277ViewDidLayout,method_getTypeEncoding(l));} SEL s=NSSelectorFromString(@"setProfileData:"); Method sm=class_getInstanceMethod(cls,s); if(sm){SX277PreviousSetProfileDataIMP=(SX277SetProfileDataIMP)method_getImplementation(sm); class_replaceMethod(cls,s,(IMP)SX277SetProfileData,method_getTypeEncoding(sm));} }); }
@end
