#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (NativeProfileTabAnimation234Private)
- (void)sx222_animateTabRegionForward:(BOOL)forward change:(dispatch_block_t)change;
@end

@implementation NativeProfileViewController (NativeProfileTabAnimation234)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(sx222_animateTabRegionForward:change:));
        Method replacement=class_getInstanceMethod(self,@selector(sx234_animateTabRegionForward:change:));
        if(target&&replacement){
            class_replaceMethod(self,
                                @selector(sx222_animateTabRegionForward:change:),
                                method_getImplementation(replacement),
                                method_getTypeEncoding(target));
        }
    });
}

- (UIView *)sx234_contentView {
    UIView *content=nil;
    @try { content=[self valueForKey:@"contentView"]; } @catch(__unused NSException *exception) {}
    return [content isKindOfClass:UIView.class]?content:nil;
}

- (UIStackView *)sx234_postsStack {
    UIView *content=[self sx234_contentView];
    if(!content)return nil;
    for(UIView *view in content.subviews){
        if(![view isKindOfClass:UIStackView.class])continue;
        UIStackView *stack=(UIStackView *)view;
        if(stack.axis==UILayoutConstraintAxisVertical)return stack;
    }
    return nil;
}

- (CGRect)sx234_visiblePostsRegion {
    [self.view layoutIfNeeded];
    UIStackView *posts=[self sx234_postsStack];
    if(!posts)return CGRectZero;

    CGRect frame=[posts convertRect:posts.bounds toView:self.view];
    CGFloat top=MAX(0,MIN(self.view.bounds.size.height,CGRectGetMinY(frame)));
    CGFloat width=self.view.bounds.size.width;
    CGFloat height=MAX(0,self.view.bounds.size.height-top);
    return CGRectMake(0,top,width,height);
}

- (void)sx234_animateTabRegionForward:(BOOL)forward change:(dispatch_block_t)change {
    CGRect oldRegion=[self sx234_visiblePostsRegion];
    if(oldRegion.size.width<=1||oldRegion.size.height<=1){
        if(change)change();
        return;
    }

    UIView *oldSnapshot=[self.view resizableSnapshotViewFromRect:oldRegion
                                              afterScreenUpdates:NO
                                                   withCapInsets:UIEdgeInsetsZero];

    if(change)change();
    [self.view layoutIfNeeded];

    CGRect newRegion=[self sx234_visiblePostsRegion];
    if(newRegion.size.width<=1||newRegion.size.height<=1)newRegion=oldRegion;
    CGFloat top=MIN(CGRectGetMinY(oldRegion),CGRectGetMinY(newRegion));
    CGRect region=CGRectMake(0,top,self.view.bounds.size.width,MAX(0,self.view.bounds.size.height-top));

    UIView *newSnapshot=[self.view resizableSnapshotViewFromRect:region
                                              afterScreenUpdates:YES
                                                   withCapInsets:UIEdgeInsetsZero];
    if(!oldSnapshot||!newSnapshot)return;

    UIView *oldWrapper=[[UIView alloc] initWithFrame:region];
    UIView *newWrapper=[[UIView alloc] initWithFrame:region];
    oldWrapper.clipsToBounds=YES;
    newWrapper.clipsToBounds=YES;
    oldWrapper.backgroundColor=self.view.backgroundColor?:UIColor.systemBackgroundColor;
    newWrapper.backgroundColor=self.view.backgroundColor?:UIColor.systemBackgroundColor;

    oldSnapshot.frame=CGRectMake(0,CGRectGetMinY(oldRegion)-top,oldRegion.size.width,oldRegion.size.height);
    newSnapshot.frame=newWrapper.bounds;
    [oldWrapper addSubview:oldSnapshot];
    [newWrapper addSubview:newSnapshot];

    CGFloat width=region.size.width;
    newWrapper.transform=CGAffineTransformMakeTranslation(forward?width:-width,0);
    [self.view addSubview:oldWrapper];
    [self.view addSubview:newWrapper];

    [UIView animateWithDuration:.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        oldWrapper.transform=CGAffineTransformMakeTranslation(forward?-width:width,0);
        newWrapper.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished){
        [oldWrapper removeFromSuperview];
        [newWrapper removeFromSuperview];
    }];
}

@end
