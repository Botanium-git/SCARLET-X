#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (IncrementalUpdate223Private)
- (NSString *)stringValue:(id)value;
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
        if(button){
            button.titleLabel.font=[UIFont systemFontOfSize:15 weight:(active?UIFontWeightBold:UIFontWeightSemibold)];
            [button setTitleColor:(active?UIColor.labelColor:UIColor.secondaryLabelColor) forState:UIControlStateNormal];
        }
        if(active){
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
    }];
}

- (void)sx223_reloadPostsStack:(UIStackView *)postsStack {
    if(!postsStack)return;
    for(UIView *view in [postsStack.arrangedSubviews copy]){
        [postsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSDictionary *data=[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{};
    NSArray *posts=[data[@"posts"] isKindOfClass:NSArray.class]?data[@"posts"]:@[];
    BOOL postsLoading=[data[@"postsLoading"] respondsToSelector:@selector(boolValue)]?[data[@"postsLoading"] boolValue]:NO;
    NSInteger selected=0;
    @try { selected=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}

    if(selected==0){
        NSInteger added=0;
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

    [self sx223_updateTabBar:[self sx223_tabBarInContent:content]];
    [self sx223_reloadPostsStack:[self sx223_postsStackInContent:content]];
    [content setNeedsLayout];
}

@end
