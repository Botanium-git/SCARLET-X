#import "NativeDrawerViewController.h"
#import "NativeProfileViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@implementation NativeDrawerViewController (NativeTransitionSpeed218)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method presentTarget=class_getInstanceMethod(self,@selector(presentInParent:));
        Method presentReplacement=class_getInstanceMethod(self,@selector(sx218_presentInParent:));
        if(presentTarget&&presentReplacement)class_replaceMethod(self,@selector(presentInParent:),method_getImplementation(presentReplacement),method_getTypeEncoding(presentTarget));

        Method dismissTarget=class_getInstanceMethod(self,@selector(dismissAnimated:));
        Method dismissReplacement=class_getInstanceMethod(self,@selector(sx218_dismissAnimated:));
        if(dismissTarget&&dismissReplacement)class_replaceMethod(self,@selector(dismissAnimated:),method_getImplementation(dismissReplacement),method_getTypeEncoding(dismissTarget));
    });
}

- (void)sx218_presentInParent:(UIViewController *)parent {
    [parent addChildViewController:self];
    self.view.frame=parent.view.bounds;
    self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [parent.view addSubview:self.view];
    [self didMoveToParentViewController:parent];
    [self.view layoutIfNeeded];

    NSLayoutConstraint *leading=nil;
    UIView *dimming=nil;
    @try { leading=[self valueForKey:@"panelLeadingConstraint"]; dimming=[self valueForKey:@"dimmingView"]; } @catch(__unused NSException *exception) {}
    if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=0;
    [UIView animateWithDuration:.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if([dimming isKindOfClass:UIView.class])dimming.alpha=1;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)sx218_dismissAnimated:(BOOL)animated {
    NSLayoutConstraint *leading=nil;
    UIView *panel=nil,*dimming=nil;
    @try { leading=[self valueForKey:@"panelLeadingConstraint"]; panel=[self valueForKey:@"panelView"]; dimming=[self valueForKey:@"dimmingView"]; } @catch(__unused NSException *exception) {}
    CGFloat width=[panel isKindOfClass:UIView.class]&&panel.bounds.size.width>0?panel.bounds.size.width:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86);
    if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=-width;
    void(^changes)(void)=^{ if([dimming isKindOfClass:UIView.class])dimming.alpha=0; [self.view layoutIfNeeded]; };
    void(^completion)(BOOL)=^(BOOL finished){ [self willMoveToParentViewController:nil]; [self.view removeFromSuperview]; [self removeFromParentViewController]; };
    if(animated)[UIView animateWithDuration:.16 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:changes completion:completion];
    else { changes(); completion(YES); }
}

@end

@implementation NativeProfileViewController (NativeTransitionSpeed218)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(closeTapped:));
        Method replacement=class_getInstanceMethod(self,@selector(sx218_closeTapped:));
        if(target&&replacement)class_replaceMethod(self,@selector(closeTapped:),method_getImplementation(replacement),method_getTypeEncoding(target));
    });
}

- (void)sx218_closeTapped:(id)sender {
    UINavigationController *nav=self.navigationController;
    if(nav.presentingViewController||self.presentingViewController){
        CATransition *transition=[CATransition animation];
        transition.duration=.20;
        transition.type=kCATransitionPush;
        transition.subtype=kCATransitionFromLeft;
        transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [self.view.window.layer addAnimation:transition forKey:@"sx218-profile-out"];
        [(nav?:self) dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    if(nav.viewControllers.count>1){[nav popViewControllerAnimated:YES];return;}
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
