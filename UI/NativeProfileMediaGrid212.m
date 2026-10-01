#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <AVKit/AVKit.h>

@interface NativeProfileViewController (MediaGrid212BaseMethods)
- (NSString *)stringValue:(id)value;
- (NSString *)displayDate:(NSString *)raw;
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
@end

@interface NativeProfileViewController (MediaGrid212)
- (UIView *)sx_212_postViewForPost:(NSDictionary *)post;
- (UIView *)sx_212_mediaTile:(NSDictionary *)media;
- (UIView *)sx_212_mediaGridForMedia:(NSArray *)mediaItems;
- (void)sx_214_playMediaTap:(UITapGestureRecognizer *)gesture;
@end

static char SX214VideoURLKey;

@implementation NativeProfileViewController (MediaGrid212)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(postViewForPost:));
        Method replacement = class_getInstanceMethod(self, @selector(sx_212_postViewForPost:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)sx_214_playMediaTap:(UITapGestureRecognizer *)gesture {
    UIView *tile = gesture.view;
    NSString *urlString = objc_getAssociatedObject(tile, &SX214VideoURLKey);
    if (![urlString isKindOfClass:NSString.class] || urlString.length == 0) return;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    AVPlayer *player = [AVPlayer playerWithURL:url];
    AVPlayerViewController *controller = [AVPlayerViewController new];
    controller.player = player;
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:controller animated:YES completion:^{
        [player play];
    }];
}

- (UIView *)sx_212_mediaTile:(NSDictionary *)media {
    UIView *container=[UIView new];
    container.translatesAutoresizingMaskIntoConstraints=NO;
    container.backgroundColor=UIColor.secondarySystemBackgroundColor;
    container.clipsToBounds=YES;

    UIImageView *image=[UIImageView new];
    image.translatesAutoresizingMaskIntoConstraints=NO;
    image.contentMode=UIViewContentModeScaleAspectFill;
    image.clipsToBounds=YES;
    [container addSubview:image];
    [NSLayoutConstraint activateConstraints:@[
        [image.topAnchor constraintEqualToAnchor:container.topAnchor],
        [image.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [image.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [image.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    NSString *preview=[self stringValue:media[@"previewURL"]];
    if(preview.length)[self loadImageURLString:preview into:image];

    NSString *type=[self stringValue:media[@"type"]];
    if([type isEqualToString:@"video"]||[type isEqualToString:@"animated_gif"]){
        UIImageView *play=[UIImageView new];
        play.translatesAutoresizingMaskIntoConstraints=NO;
        play.image=[UIImage systemImageNamed:@"play.circle.fill"];
        play.tintColor=UIColor.whiteColor;
        play.contentMode=UIViewContentModeScaleAspectFit;
        play.layer.shadowColor=UIColor.blackColor.CGColor;
        play.layer.shadowOpacity=.55;
        play.layer.shadowRadius=3;
        play.layer.shadowOffset=CGSizeZero;
        [container addSubview:play];
        [NSLayoutConstraint activateConstraints:@[
            [play.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [play.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [play.widthAnchor constraintEqualToConstant:44],
            [play.heightAnchor constraintEqualToConstant:44]
        ]];

        NSString *videoURL=[self stringValue:media[@"videoURL"]];
        if(videoURL.length){
            objc_setAssociatedObject(container, &SX214VideoURLKey, videoURL, OBJC_ASSOCIATION_COPY_NONATOMIC);
            container.userInteractionEnabled=YES;
            UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sx_214_playMediaTap:)];
            [container addGestureRecognizer:tap];
        }
    }
    return container;
}

- (UIView *)sx_212_mediaGridForMedia:(NSArray *)mediaItems {
    NSArray *items=mediaItems.count>4?[mediaItems subarrayWithRange:NSMakeRange(0,4)]:mediaItems;
    if(items.count==0)return nil;

    UIView *(^tileAt)(NSUInteger)=^UIView *(NSUInteger idx){
        id obj=items[idx];
        return [self sx_212_mediaTile:[obj isKindOfClass:NSDictionary.class]?obj:@{}];
    };

    if(items.count==1){
        UIView *tile=tileAt(0);
        tile.layer.cornerRadius=12;
        [tile.heightAnchor constraintEqualToConstant:220].active=YES;
        return tile;
    }

    if(items.count==2){
        UIStackView *row=[UIStackView new];
        row.axis=UILayoutConstraintAxisHorizontal;
        row.spacing=2;
        row.distribution=UIStackViewDistributionFillEqually;
        [row addArrangedSubview:tileAt(0)];
        [row addArrangedSubview:tileAt(1)];
        row.clipsToBounds=YES;
        row.layer.cornerRadius=12;
        [row.heightAnchor constraintEqualToConstant:220].active=YES;
        return row;
    }

    if(items.count==3){
        UIStackView *right=[UIStackView new];
        right.axis=UILayoutConstraintAxisVertical;
        right.spacing=2;
        right.distribution=UIStackViewDistributionFillEqually;
        [right addArrangedSubview:tileAt(1)];
        [right addArrangedSubview:tileAt(2)];

        UIStackView *row=[UIStackView new];
        row.axis=UILayoutConstraintAxisHorizontal;
        row.spacing=2;
        row.distribution=UIStackViewDistributionFillEqually;
        [row addArrangedSubview:tileAt(0)];
        [row addArrangedSubview:right];
        row.clipsToBounds=YES;
        row.layer.cornerRadius=12;
        [row.heightAnchor constraintEqualToConstant:240].active=YES;
        return row;
    }

    UIStackView *top=[UIStackView new];
    top.axis=UILayoutConstraintAxisHorizontal;
    top.spacing=2;
    top.distribution=UIStackViewDistributionFillEqually;
    [top addArrangedSubview:tileAt(0)];
    [top addArrangedSubview:tileAt(1)];

    UIStackView *bottom=[UIStackView new];
    bottom.axis=UILayoutConstraintAxisHorizontal;
    bottom.spacing=2;
    bottom.distribution=UIStackViewDistributionFillEqually;
    [bottom addArrangedSubview:tileAt(2)];
    [bottom addArrangedSubview:tileAt(3)];

    UIStackView *grid=[UIStackView new];
    grid.axis=UILayoutConstraintAxisVertical;
    grid.spacing=2;
    grid.distribution=UIStackViewDistributionFillEqually;
    [grid addArrangedSubview:top];
    [grid addArrangedSubview:bottom];
    grid.clipsToBounds=YES;
    grid.layer.cornerRadius=12;
    [grid.heightAnchor constraintEqualToConstant:260].active=YES;
    return grid;
}

- (NSString *)sx_215_inlineDate:(NSString *)raw {
    if(raw.length==0)return @"";
    NSDateFormatter *input=[NSDateFormatter new];
    input.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    input.dateFormat=@"EEE MMM dd HH:mm:ss Z yyyy";
    NSDate *date=[input dateFromString:raw];
    if(!date)return @"";
    NSDateFormatter *output=[NSDateFormatter new];
    output.locale=[NSLocale currentLocale];
    output.dateFormat=@"M/d";
    return [output stringFromDate:date];
}

- (UIView *)sx_215_actionItemWithSymbol:(NSString *)symbol count:(NSNumber *)count {
    UIStackView *item=[UIStackView new];
    item.axis=UILayoutConstraintAxisHorizontal;
    item.alignment=UIStackViewAlignmentCenter;
    item.spacing=5;

    UIImageView *icon=[UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints=NO;
    icon.image=[UIImage systemImageNamed:symbol];
    icon.tintColor=UIColor.secondaryLabelColor;
    icon.contentMode=UIViewContentModeScaleAspectFit;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:17],
        [icon.heightAnchor constraintEqualToConstant:17]
    ]];
    [item addArrangedSubview:icon];

    NSInteger value=[count respondsToSelector:@selector(integerValue)]?[count integerValue]:0;
    if(value>0){
        UILabel *label=[UILabel new];
        label.font=[UIFont systemFontOfSize:12];
        label.textColor=UIColor.secondaryLabelColor;
        label.text=[NSString stringWithFormat:@"%ld",(long)value];
        [item addArrangedSubview:label];
    }
    return item;
}

- (UIView *)sx_212_postViewForPost:(NSDictionary *)post {
    NSDictionary *profile=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSString *name=[self stringValue:profile[@"name"]];
    NSString *handle=[self stringValue:profile[@"handle"]];
    NSString *avatarURL=[self stringValue:profile[@"avatarURL"]];
    if(handle.length && ![handle hasPrefix:@"@"])handle=[@"@" stringByAppendingString:handle];

    UIStackView *root=[UIStackView new];
    root.axis=UILayoutConstraintAxisVertical;
    root.spacing=0;

    UIStackView *row=[UIStackView new];
    row.axis=UILayoutConstraintAxisHorizontal;
    row.alignment=UIStackViewAlignmentTop;
    row.spacing=10;
    row.layoutMargins=UIEdgeInsetsMake(11,12,8,12);
    row.layoutMarginsRelativeArrangement=YES;
    [root addArrangedSubview:row];

    UIImageView *avatar=[UIImageView new];
    avatar.translatesAutoresizingMaskIntoConstraints=NO;
    avatar.backgroundColor=UIColor.secondarySystemBackgroundColor;
    avatar.contentMode=UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds=YES;
    avatar.layer.cornerRadius=20;
    avatar.image=[UIImage systemImageNamed:@"person.crop.circle.fill"];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:40],
        [avatar.heightAnchor constraintEqualToConstant:40]
    ]];
    [row addArrangedSubview:avatar];
    if(avatarURL.length)[self loadImageURLString:avatarURL into:avatar];

    UIStackView *content=[UIStackView new];
    content.axis=UILayoutConstraintAxisVertical;
    content.alignment=UIStackViewAlignmentFill;
    content.spacing=5;
    [row addArrangedSubview:content];

    UIStackView *header=[UIStackView new];
    header.axis=UILayoutConstraintAxisHorizontal;
    header.alignment=UIStackViewAlignmentCenter;
    header.spacing=4;
    [content addArrangedSubview:header];

    UILabel *nameLabel=[UILabel new];
    nameLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    nameLabel.text=name;
    nameLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:nameLabel];

    UILabel *meta=[UILabel new];
    meta.font=[UIFont systemFontOfSize:15];
    meta.textColor=UIColor.secondaryLabelColor;
    NSString *date=[self sx_215_inlineDate:[self stringValue:post[@"createdAt"]]];
    if(handle.length&&date.length)meta.text=[NSString stringWithFormat:@"%@ · %@",handle,date];
    else meta.text=handle.length?handle:date;
    meta.lineBreakMode=NSLineBreakByTruncatingTail;
    [meta setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:meta];

    UIView *spacer=[UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:spacer];

    UIImageView *more=[UIImageView new];
    more.translatesAutoresizingMaskIntoConstraints=NO;
    more.image=[UIImage systemImageNamed:@"ellipsis"];
    more.tintColor=UIColor.secondaryLabelColor;
    more.contentMode=UIViewContentModeScaleAspectFit;
    [NSLayoutConstraint activateConstraints:@[
        [more.widthAnchor constraintEqualToConstant:18],
        [more.heightAnchor constraintEqualToConstant:18]
    ]];
    [header addArrangedSubview:more];

    NSString *text=[self stringValue:post[@"text"]];
    if(text.length){
        UILabel *body=[UILabel new];
        body.font=[UIFont systemFontOfSize:15];
        body.numberOfLines=0;
        body.text=text;
        [content addArrangedSubview:body];
    }

    NSArray *media=[post[@"media"] isKindOfClass:NSArray.class]?post[@"media"]:@[];
    if(media.count==0){
        NSString *legacyURL=[self stringValue:post[@"mediaURL"]];
        if(legacyURL.length)media=@[@{@"type":@"photo",@"previewURL":legacyURL}];
    }
    UIView *mediaGrid=[self sx_212_mediaGridForMedia:media];
    if(mediaGrid){
        [content setCustomSpacing:9 afterView:content.arrangedSubviews.lastObject];
        [content addArrangedSubview:mediaGrid];
    }

    NSNumber *reply=[post[@"replyCount"] isKindOfClass:NSNumber.class]?post[@"replyCount"]:@0;
    NSNumber *retweet=[post[@"retweetCount"] isKindOfClass:NSNumber.class]?post[@"retweetCount"]:@0;
    NSNumber *favorite=[post[@"favoriteCount"] isKindOfClass:NSNumber.class]?post[@"favoriteCount"]:@0;

    UIStackView *actions=[UIStackView new];
    actions.axis=UILayoutConstraintAxisHorizontal;
    actions.alignment=UIStackViewAlignmentCenter;
    actions.distribution=UIStackViewDistributionEqualSpacing;
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"bubble" count:reply]];
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"arrow.2.squarepath" count:retweet]];
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"heart" count:favorite]];
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"chart.bar" count:nil]];
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"bookmark" count:nil]];
    [actions addArrangedSubview:[self sx_215_actionItemWithSymbol:@"square.and.arrow.up" count:nil]];
    [actions.heightAnchor constraintEqualToConstant:28].active=YES;
    [content setCustomSpacing:5 afterView:content.arrangedSubviews.lastObject];
    [content addArrangedSubview:actions];

    UIView *separator=[UIView new];
    separator.translatesAutoresizingMaskIntoConstraints=NO;
    separator.backgroundColor=UIColor.separatorColor;
    [separator.heightAnchor constraintEqualToConstant:.5].active=YES;
    [root addArrangedSubview:separator];
    return root;
}

@end
