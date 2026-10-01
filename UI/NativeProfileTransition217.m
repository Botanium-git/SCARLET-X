#import "NativeProfileViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@implementation NativeProfileViewController (NativeProfileTransition217)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(closeTapped:));
        Method replacement=class_getInstanceMethod(self,@selector(sx217_closeTapped:));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx217_closeTapped:(id)sender {
    UINavigationController *nav=self.navigationController;
    if(nav.presentingViewController||self.presentingViewController){
        CATransition *transition=[CATransition animation];
        transition.duration=.26;
        transition.type=kCATransitionPush;
        transition.subtype=kCATransitionFromLeft;
        transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [self.view.window.layer addAnimation:transition forKey:@"sx217-profile-out"];
        [(nav?:self) dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    if(nav.viewControllers.count>1){[nav popViewControllerAnimated:YES];return;}
    [self sx217_closeTapped:sender];
}

@end
