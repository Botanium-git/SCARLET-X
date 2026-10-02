#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char SX237RepostDisplayLimitKey;

@interface NativeProfileViewController (IncrementalUpdate223Private)
- (NSString *)stringValue:(id)value;
- (NSString *)joinedTextForRaw:(NSString *)raw;
- (void)loadImageURLString:(NSString *)urlString into:(UIImageView *)imageView;
- (UIView *)postViewForPost:(NSDictionary *)post;
@end

@implementation NativeProfileViewController (IncrementalUpdate223)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(applyProfileData:));
        Method replacement=class_getInstanceMethod(self,@selector(sx223_applyProfileData:));
        if(target&&replacement){
            class_replaceMethod(self,@selector(applyProfileData:),method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (UIView *)sx223_contentView {
    UIView *content=nil;
    @try { content=[self valueForKey:@"contentView"]; } @catch(__unused NSException *exception) {}
    return [content isKindOfClass:UIView.class]?content:nil;
}

- (UIStackView *)sx223_tabBarInContent:(UIView *)content {
    for(UIView *view in content.subviews){
        if(![view isKindOfClass:UIStackView.class])continue;
        UIStackView *stack=(UIStackView *)view;
        if(stack.axis==UILayoutConstraintAxisHorizontal&&stack.arrangedSubviews.count==4)return stack;
    }
    return nil;
}

- (UIStackView *)sx223_postsStackInContent:(UIView *)content {
    for(UIView *view in content.subviews){
        if(![view isKindOfClass:UIStackView.class])continue;
        UIStackView *stack=(UIStackView *)view;
        if(stack.axis==UILayoutConstraintAxisVertical)return stack;
    }
    return nil;
}

- (NSArray<UIImageView *> *)sx223_directImageViews:(UIView *)content {
    NSMutableArray *result=[NSMutableArray array];
    for(UIView *view in content.subviews)if([view isKindOfClass:UIImageView.class])[result addObject:(UIImageView *)view];
    return result;
}

- (NSArray<UILabel *> *)sx223_directLabels:(UIView *)content {
    NSMutableArray *result=[NSMutableArray array];
    for(UIView *view in content.subviews)if([view isKindOfClass:UILabel.class])[result addObject:(UILabel *)view];
    return result;
}

- (UIView *)sx223_findViewWithAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)root {
    if([root.accessibilityIdentifier isEqualToString:identifier])return root;
    for(UIView *sub in root.subviews){
        UIView *match=[self sx223_findViewWithAccessibilityIdentifier:identifier inView:sub];
        if(match)return match;
    }
    return nil;
}

- (void)sx223_updateJoinedDateInContent:(UIView *)content data:(NSDictionary *)data {
    UILabel *label=(UILabel *)[self sx223_findViewWithAccessibilityIdentifier:@"sx.profile.joined.label" inView:content];
    UIView *container=[self sx223_findViewWithAccessibilityIdentifier:@"sx.profile.joined.container" inView:content];
    if(![label isKindOfClass:UILabel.class]||![container isKindOfClass:UIView.class])return;
    NSString *joined=[self joinedTextForRaw:[self stringValue:data[@"createdAt"]]];
    label.text=joined;
    for(NSLayoutConstraint *constraint in container.constraints){
        if([constraint.identifier isEqualToString:@"sx.profile.joined.height"]){
            constraint.constant=joined.length?20:0;
            break;
        }
    }
}

- (void)sx223_updateTabBar:(UIStackView *)tabBar {
    if(!tabBar)return;
    NSInteger selected=0;
    @try { selected=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}

    [tabBar.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *container,NSUInteger idx,BOOL *stop){
        UIButton *button=nil;
        NSMutableArray<UIView *> *remove=[NSMutableArray array];
        for(UIView *sub in container.subviews){
            if([sub isKindOfClass:UIButton.class])button=(UIButton *)sub;
            else [remove addObject:sub];
        }
        for(UIView *sub in remove)[sub removeFromSuperview];

        BOOL active=(idx==(NSUInteger)selected);
        UIColor *tint=active?UIColor.labelColor:UIColor.secondaryLabelColor;
        if(button){
            button.titleLabel.font=[UIFont systemFontOfSize:15 weight:(idx==0?UIFontWeightBold:UIFontWeightSemibold)];
            [button setTitleColor:tint forState:UIControlStateNormal];
            button.tintColor=tint;
        }
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
    }];
}

- (NSInteger)sx237_repostDisplayLimit {
    NSNumber *stored=objc_getAssociatedObject(self,&SX237RepostDisplayLimitKey);
    NSInteger value=[stored respondsToSelector:@selector(integerValue)]?[stored integerValue]:0;
    return value>0?value:8;
}

- (void)sx237_showMoreReposts:(UIButton *)sender {
    NSInteger next=[self sx237_repostDisplayLimit]+8;
    objc_setAssociatedObject(self,&SX237RepostDisplayLimitKey,@(next),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIView *content=[self sx223_contentView];
    UIStackView *postsStack=[self sx223_postsStackInContent:content];
    [self sx223_reloadPostsStack:postsStack];
}

- (void)sx238_loadMoreTimeline:(UIButton *)sender {
    UIViewController *presenter=self.navigationController.presentingViewController ?: self.presentingViewController;
    SEL selector=NSSelectorFromString(@"sx238_loadMoreProfile:");
    if(presenter&&[presenter respondsToSelector:selector]){
        ((void(*)(id,SEL,id))objc_msgSend)(presenter,selector,self);
    }
}

- (UIButton *)sx238_moreButtonWithTitle:(NSString *)title action:(SEL)action enabled:(BOOL)enabled {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints=NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.enabled=enabled;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:48].active=YES;
    return button;
}

- (void)sx223_reloadPostsStack:(UIStackView *)postsStack {
    if(!postsStack)return;
    for(UIView *view in [postsStack.arrangedSubviews copy]){
        [postsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSDictionary *data=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSInteger selected=0;
    @try { selected=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}

    if(selected>=0&&selected<=2){
        NSArray<NSString *> *itemsKeys=@[@"posts",@"replies",@"reposts"];
        NSArray<NSString *> *loadingKeys=@[@"postsLoading",@"repliesLoading",@"repostsLoading"];
        NSArray<NSString *> *moreLoadingKeys=@[@"postsMoreLoading",@"repliesMoreLoading",@"repostsMoreLoading"];
        NSArray<NSString *> *hasMoreKeys=@[@"postsHasMore",@"repliesHasMore",@"repostsHasMore"];
        NSArray<NSString *> *loadingTexts=@[@"Xからポストを読み込み中…",@"Xから返信を読み込み中…",@"Xからリポストを読み込み中…"];
        NSArray<NSString *> *emptyTexts=@[@"通常ポストはありません",@"返信はありません",@"リポストはありません"];
        NSString *itemsKey=itemsKeys[(NSUInteger)selected];
        NSString *loadingKey=loadingKeys[(NSUInteger)selected];
        NSString *moreLoadingKey=moreLoadingKeys[(NSUInteger)selected];
        NSString *hasMoreKey=hasMoreKeys[(NSUInteger)selected];
        NSArray *items=[data[itemsKey] isKindOfClass:NSArray.class]?data[itemsKey]:@[];
        BOOL hasLoading=[data[loadingKey] respondsToSelector:@selector(boolValue)];
        BOOL loading=hasLoading?[data[loadingKey] boolValue]:(![data.allKeys containsObject:itemsKey]);
        BOOL moreLoading=[data[moreLoadingKey] respondsToSelector:@selector(boolValue)]?[data[moreLoadingKey] boolValue]:NO;
        BOOL hasMore=[data[hasMoreKey] respondsToSelector:@selector(boolValue)]?[data[hasMoreKey] boolValue]:(items.count>0);
        NSUInteger renderCount=items.count;
        if(selected==2)renderCount=MIN(items.count,(NSUInteger)[self sx237_repostDisplayLimit]);
        NSInteger added=0;
        for(NSUInteger idx=0;idx<renderCount;idx++){
            id item=items[idx];
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
            empty.text=loading?loadingTexts[(NSUInteger)selected]:emptyTexts[(NSUInteger)selected];
            [postsStack addArrangedSubview:empty];
            [empty.heightAnchor constraintGreaterThanOrEqualToConstant:100].active=YES;
        } else if(selected==2&&renderCount<items.count){
            [postsStack addArrangedSubview:[self sx238_moreButtonWithTitle:@"さらに表示" action:@selector(sx237_showMoreReposts:) enabled:YES]];
        } else if(hasMore){
            NSString *title=moreLoading?@"読み込み中…":@"さらに読み込む";
            [postsStack addArrangedSubview:[self sx238_moreButtonWithTitle:title action:@selector(sx238_loadMoreTimeline:) enabled:!moreLoading]];
        }
    } else {
        UILabel *empty=[UILabel new];
        empty.font=[UIFont systemFontOfSize:14];
        empty.textColor=UIColor.secondaryLabelColor;
        empty.textAlignment=NSTextAlignmentCenter;
        empty.text=@"メディアはまだ接続していません";
        [postsStack addArrangedSubview:empty];
        [empty.heightAnchor constraintGreaterThanOrEqualToConstant:120].active=YES;
    }
}

- (void)sx223_applyProfileData:(NSDictionary *)profileData {
    NSDictionary *old=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSDictionary *next=[profileData isKindOfClass:NSDictionary.class]?[profileData copy]:@{};
    self.profileData=next;
    if(!self.isViewLoaded)return;

    UIView *content=[self sx223_contentView];
    if(!content)return;

    NSArray<UIImageView *> *images=[self sx223_directImageViews:content];
    UIImageView *banner=images.count>0?images[0]:nil;
    UIImageView *avatar=images.count>1?images[1]:nil;
    NSString *oldBanner=[self stringValue:old[@"bannerURL"]];
    NSString *newBanner=[self stringValue:next[@"bannerURL"]];
    NSString *oldAvatar=[self stringValue:old[@"avatarURL"]];
    NSString *newAvatar=[self stringValue:next[@"avatarURL"]];
    if(banner&&newBanner.length&&![newBanner isEqualToString:oldBanner])[self loadImageURLString:newBanner into:banner];
    if(avatar&&newAvatar.length&&![newAvatar isEqualToString:oldAvatar])[self loadImageURLString:newAvatar into:avatar];

    NSArray<UILabel *> *labels=[self sx223_directLabels:content];
    if(labels.count>=4){
        UILabel *nameLabel=labels[0];
        UILabel *handleLabel=labels[1];
        UILabel *bioLabel=labels[2];
        UILabel *countsLabel=labels[3];
        nameLabel.text=[self stringValue:next[@"name"]];
        handleLabel.text=[self stringValue:next[@"handle"]];
        bioLabel.text=[self stringValue:next[@"bio"]];

        NSDictionary *followerProbe=[next[@"followerProbe"] isKindOfClass:NSDictionary.class]?next[@"followerProbe"]:@{};
        NSDictionary *counts=[followerProbe[@"counts"] isKindOfClass:NSDictionary.class]?followerProbe[@"counts"]:@{};
        NSString *following=[self stringValue:next[@"following"]];
        NSString *followers=[self stringValue:next[@"followers"]];
        if(following.length==0)following=[self stringValue:counts[@"friends_count"]];
        if(following.length==0)following=[self stringValue:counts[@"legacy.friends_count"]];
        if(followers.length==0)followers=[self stringValue:counts[@"followers_count"]];
        if(followers.length==0)followers=[self stringValue:counts[@"legacy.followers_count"]];
        countsLabel.text=[NSString stringWithFormat:@"%@ フォロー中    %@ フォロワー",following.length?following:@"—",followers.length?followers:@"—"];
    }

    [self sx223_updateJoinedDateInContent:content data:next];
    [self sx223_updateTabBar:[self sx223_tabBarInContent:content]];
    [self sx223_reloadPostsStack:[self sx223_postsStackInContent:content]];
    [content setNeedsLayout];
}

@end
