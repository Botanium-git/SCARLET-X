#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (MediaGrid212)
- (NSString *)stringValue:(id)value;
- (NSString *)displayDate:(NSString *)raw;
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
- (UIView *)sx_212_postViewForPost:(NSDictionary *)post;
@end

@implementation NativeProfileViewController (MediaGrid212)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(postViewForPost:));
        Method replacement = class_getInstanceMethod(self, @selector(sx_212_postViewForPost:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
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

- (UIView *)sx_212_postViewForPost:(NSDictionary *)post {
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

    NSString *text=[self stringValue:post[@"text"]];
    if(text.length){
        UILabel *body=[UILabel new];
        body.font=[UIFont systemFontOfSize:15];
        body.numberOfLines=0;
        body.text=text;
        [stack addArrangedSubview:body];
    }

    NSArray *media=[post[@"media"] isKindOfClass:NSArray.class]?post[@"media"]:@[];
    if(media.count==0){
        NSString *legacyURL=[self stringValue:post[@"mediaURL"]];
        if(legacyURL.length)media=@[@{@"type":@"photo",@"previewURL":legacyURL}];
    }
    UIView *mediaGrid=[self sx_212_mediaGridForMedia:media];
    if(mediaGrid)[stack addArrangedSubview:mediaGrid];

    NSNumber *reply=[post[@"replyCount"] isKindOfClass:NSNumber.class]?post[@"replyCount"]:@0;
    NSNumber *retweet=[post[@"retweetCount"] isKindOfClass:NSNumber.class]?post[@"retweetCount"]:@0;
    NSNumber *favorite=[post[@"favoriteCount"] isKindOfClass:NSNumber.class]?post[@"favoriteCount"]:@0;
    UILabel *counts=[UILabel new];
    counts.font=[UIFont systemFontOfSize:13];
    counts.textColor=UIColor.secondaryLabelColor;
    counts.numberOfLines=1;
    counts.text=[NSString stringWithFormat:@"返信 %@    リポスト %@    いいね %@",reply,retweet,favorite];
    [stack addArrangedSubview:counts];

    UIView *separator=[UIView new];
    separator.translatesAutoresizingMaskIntoConstraints=NO;
    separator.backgroundColor=UIColor.separatorColor;
    [separator.heightAnchor constraintEqualToConstant:.5].active=YES;
    [stack addArrangedSubview:separator];
    return stack;
}

@end
