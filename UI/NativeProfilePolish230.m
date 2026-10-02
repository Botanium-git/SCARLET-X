#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (NativeProfilePolish230Private)
- (void)buildUI;
@end

@implementation NativeProfileViewController (NativeProfilePolish230)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method buildOriginal=class_getInstanceMethod(self,@selector(buildUI));
        Method buildReplacement=class_getInstanceMethod(self,@selector(sx230_buildUI));
        if(buildOriginal&&buildReplacement)method_exchangeImplementations(buildOriginal,buildReplacement);

        Method applyOriginal=class_getInstanceMethod(self,@selector(applyProfileData:));
        Method applyReplacement=class_getInstanceMethod(self,@selector(sx230_applyProfileData:));
        if(applyOriginal&&applyReplacement)method_exchangeImplementations(applyOriginal,applyReplacement);
    });
}

- (UIView *)sx230_contentView {
    UIView *content=nil;
    @try { content=[self valueForKey:@"contentView"]; } @catch(__unused NSException *exception) {}
    return [content isKindOfClass:UIView.class]?content:nil;
}

- (UIView *)sx230_findAccessibilityIdentifier:(NSString *)identifier inView:(UIView *)root {
    if([root.accessibilityIdentifier isEqualToString:identifier])return root;
    for(UIView *sub in root.subviews){
        UIView *match=[self sx230_findAccessibilityIdentifier:identifier inView:sub];
        if(match)return match;
    }
    return nil;
}

- (void)sx230_applyProfileData:(NSDictionary *)profileData {
    NSDictionary *incoming=[profileData isKindOfClass:NSDictionary.class]?profileData:@{};
    NSMutableDictionary *merged=[[self.profileData isKindOfClass:NSDictionary.class]?self.profileData:@{} mutableCopy];
    [merged addEntriesFromDictionary:incoming];
    [self sx230_applyProfileData:merged];
}

- (void)sx230_buildUI {
    [self sx230_buildUI];

    UIView *content=[self sx230_contentView];
    if(!content)return;

    NSMutableArray<UILabel *> *labels=[NSMutableArray array];
    NSMutableArray<UIImageView *> *images=[NSMutableArray array];
    UIButton *verify=nil;
    UIStackView *actions=nil;
    UIStackView *tabs=nil;

    for(UIView *view in content.subviews){
        if([view isKindOfClass:UILabel.class]){
            [labels addObject:(UILabel *)view];
        } else if([view isKindOfClass:UIImageView.class]){
            [images addObject:(UIImageView *)view];
        } else if([view isKindOfClass:UIButton.class]){
            UIButton *button=(UIButton *)view;
            NSString *title=[button titleForState:UIControlStateNormal]?:@"";
            if([title isEqualToString:@"認証を受ける"])verify=button;
        } else if([view isKindOfClass:UIStackView.class]){
            UIStackView *stack=(UIStackView *)view;
            if(stack.axis==UILayoutConstraintAxisHorizontal&&stack.arrangedSubviews.count==2)actions=stack;
            else if(stack.axis==UILayoutConstraintAxisHorizontal&&stack.arrangedSubviews.count==4)tabs=stack;
        }
    }

    UILabel *nameLabel=labels.count>0?labels[0]:nil;
    UILabel *handleLabel=labels.count>1?labels[1]:nil;
    UILabel *bioLabel=labels.count>2?labels[2]:nil;
    UILabel *countsLabel=labels.count>3?labels[3]:nil;
    UIImageView *avatar=images.count>1?images[1]:nil;

    nameLabel.font=[UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    handleLabel.font=[UIFont systemFontOfSize:14];
    bioLabel.font=[UIFont systemFontOfSize:14];
    countsLabel.font=[UIFont systemFontOfSize:13];

    UIView *joinedContainer=[self sx230_findAccessibilityIdentifier:@"sx.profile.joined.container" inView:content];
    UILabel *joinedLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.joined.label" inView:content];
    if([joinedLabel isKindOfClass:UILabel.class])joinedLabel.font=[UIFont systemFontOfSize:13];
    if([joinedContainer isKindOfClass:UIView.class])joinedContainer.hidden=(joinedLabel.text.length==0);

    if(verify){
        verify.titleLabel.font=[UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        verify.layer.cornerRadius=14;
        for(NSLayoutConstraint *constraint in [content.constraints copy]){
            BOOL trailing=(constraint.firstItem==verify&&constraint.firstAttribute==NSLayoutAttributeTrailing&&constraint.secondItem==content);
            BOOL nameToVerify=(constraint.firstItem==nameLabel&&constraint.firstAttribute==NSLayoutAttributeTrailing&&constraint.secondItem==verify&&constraint.secondAttribute==NSLayoutAttributeLeading);
            if(trailing||nameToVerify)constraint.active=NO;
        }
        for(NSLayoutConstraint *constraint in verify.constraints){
            if(constraint.firstAttribute==NSLayoutAttributeHeight&&constraint.secondItem==nil)constraint.constant=28;
        }
        if(nameLabel){
            [NSLayoutConstraint activateConstraints:@[
                [verify.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:8],
                [verify.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-16]
            ]];
            [nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
            [verify setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        }
    }

    for(NSLayoutConstraint *constraint in content.constraints){
        if(constraint.firstItem==nameLabel&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==avatar&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=10;
        else if(constraint.firstItem==handleLabel&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==nameLabel&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=1;
        else if(constraint.firstItem==bioLabel&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==handleLabel&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=12;
        else if(constraint.firstItem==joinedContainer&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==bioLabel&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=8;
        else if(constraint.firstItem==countsLabel&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==joinedContainer&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=8;
        else if(constraint.firstItem==actions&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==countsLabel&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=14;
        else if(constraint.firstItem!=nil&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==actions&&constraint.secondAttribute==NSLayoutAttributeBottom)constraint.constant=10;
    }

    if(actions){
        for(NSLayoutConstraint *constraint in actions.constraints){
            if(constraint.firstAttribute==NSLayoutAttributeHeight&&constraint.secondItem==nil)constraint.constant=38;
        }
        for(UIView *view in actions.arrangedSubviews){
            if(![view isKindOfClass:UIButton.class])continue;
            UIButton *button=(UIButton *)view;
            button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            button.layer.cornerRadius=19;
        }
    }

    if(tabs){
        for(NSLayoutConstraint *constraint in tabs.constraints){
            if(constraint.firstAttribute==NSLayoutAttributeHeight&&constraint.secondItem==nil)constraint.constant=52;
        }
        UIImageSymbolConfiguration *config=[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        for(UIView *container in tabs.arrangedSubviews){
            for(UIView *sub in container.subviews){
                if(![sub isKindOfClass:UIButton.class])continue;
                UIButton *button=(UIButton *)sub;
                [button setPreferredSymbolConfiguration:config forImageInState:UIControlStateNormal];
                if(button.tag==0)button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
            }
        }
    }

    [content setNeedsLayout];
    [content layoutIfNeeded];
}

@end
