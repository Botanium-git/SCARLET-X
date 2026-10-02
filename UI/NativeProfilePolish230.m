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

- (void)sx231_shareProfile:(UIButton *)sender {
    NSString *handle=[self.profileData[@"handle"] isKindOfClass:NSString.class]?self.profileData[@"handle"]:@"";
    NSString *screen=[handle hasPrefix:@"@"]?[handle substringFromIndex:1]:handle;
    if(screen.length==0)return;
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://x.com/%@",screen]];
    if(!url)return;

    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if(UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad){
        UIPopoverPresentationController *popover=share.popoverPresentationController;
        popover.sourceView=sender;
        popover.sourceRect=sender.bounds;
    } else {
        share.modalPresentationStyle=UIModalPresentationPageSheet;
    }
    [self presentViewController:share animated:YES completion:nil];
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
    UIImageView *banner=images.count>0?images[0]:nil;
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
    }

    if(actions&&actions.arrangedSubviews.count>=2&&banner&&countsLabel){
        UIButton *edit=[actions.arrangedSubviews[1] isKindOfClass:UIButton.class]?(UIButton *)actions.arrangedSubviews[1]:nil;
        UIView *separator=nil;
        NSMutableArray<NSLayoutConstraint *> *remove=[NSMutableArray array];
        for(NSLayoutConstraint *constraint in content.constraints){
            if(constraint.firstItem==actions||constraint.secondItem==actions){
                if(constraint.firstItem!=actions&&constraint.firstAttribute==NSLayoutAttributeTop&&constraint.secondItem==actions&&constraint.secondAttribute==NSLayoutAttributeBottom)separator=constraint.firstItem;
                [remove addObject:constraint];
            }
        }
        [NSLayoutConstraint deactivateConstraints:remove];
        if(edit){
            [actions removeArrangedSubview:edit];
            [edit removeFromSuperview];
        }
        [actions removeFromSuperview];

        if(edit){
            edit.translatesAutoresizingMaskIntoConstraints=NO;
            edit.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            edit.layer.cornerRadius=18;
            [content addSubview:edit];
            [NSLayoutConstraint activateConstraints:@[
                [edit.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
                [edit.topAnchor constraintEqualToAnchor:banner.bottomAnchor constant:12],
                [edit.heightAnchor constraintEqualToConstant:36],
                [edit.widthAnchor constraintGreaterThanOrEqualToConstant:156]
            ]];
        }
        if(separator){
            [NSLayoutConstraint activateConstraints:@[
                [separator.topAnchor constraintEqualToAnchor:countsLabel.bottomAnchor constant:20]
            ]];
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

    if(![self sx230_findAccessibilityIdentifier:@"sx.profile.share.top" inView:self.view]){
        UIButton *share=[UIButton buttonWithType:UIButtonTypeSystem];
        share.translatesAutoresizingMaskIntoConstraints=NO;
        share.accessibilityIdentifier=@"sx.profile.share.top";
        share.backgroundColor=[UIColor colorWithWhite:0 alpha:.58];
        share.tintColor=UIColor.whiteColor;
        share.layer.cornerRadius=19;
        [share setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        [share addTarget:self action:@selector(sx231_shareProfile:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:share];
        UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [share.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-62],
            [share.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
            [share.widthAnchor constraintEqualToConstant:38],
            [share.heightAnchor constraintEqualToConstant:38]
        ]];
    }

    [content setNeedsLayout];
    [content layoutIfNeeded];
}

@end
