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
    if(UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPad){
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

    UILabel *nameLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.name" inView:content];
    UIStackView *nameRow=(UIStackView *)[self sx230_findAccessibilityIdentifier:@"sx.profile.name.row" inView:content];
    UILabel *handleLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.handle" inView:content];
    UILabel *bioLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.bio" inView:content];
    UILabel *countsLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.counts" inView:content];
    UIView *joinedContainer=[self sx230_findAccessibilityIdentifier:@"sx.profile.joined.container" inView:content];
    UILabel *joinedLabel=(UILabel *)[self sx230_findAccessibilityIdentifier:@"sx.profile.joined.label" inView:content];
    UIButton *edit=(UIButton *)[self sx230_findAccessibilityIdentifier:@"sx.profile.edit" inView:content];

    if([nameLabel isKindOfClass:UILabel.class]) nameLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    if([handleLabel isKindOfClass:UILabel.class]) handleLabel.font=[UIFont systemFontOfSize:15];
    if([bioLabel isKindOfClass:UILabel.class]) bioLabel.font=[UIFont systemFontOfSize:15];
    if([countsLabel isKindOfClass:UILabel.class]) countsLabel.font=[UIFont systemFontOfSize:14];
    if([joinedLabel isKindOfClass:UILabel.class]) joinedLabel.font=[UIFont systemFontOfSize:14];
    if([joinedContainer isKindOfClass:UIView.class]) joinedContainer.hidden=(joinedLabel.text.length==0);

    if([edit isKindOfClass:UIButton.class]){
        edit.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        edit.layer.cornerRadius=17;
        [edit setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [edit setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }
    if([nameRow isKindOfClass:UIStackView.class]){
        nameRow.spacing=2.5;
        [nameRow setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    }

    UIStackView *tabs=nil;
    for(UIView *view in content.subviews){
        if([view isKindOfClass:UIStackView.class]){
            UIStackView *stack=(UIStackView *)view;
            if(stack.axis==UILayoutConstraintAxisHorizontal&&stack.arrangedSubviews.count==4){tabs=stack;break;}
        }
    }
    if(tabs){
        for(NSLayoutConstraint *constraint in content.constraints){
            if(constraint.firstItem==tabs&&constraint.firstAttribute==NSLayoutAttributeHeight&&constraint.secondItem==nil) constraint.constant=52;
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
