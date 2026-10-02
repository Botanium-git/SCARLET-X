#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@implementation NativeProfileViewController (NativePolish225)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method target=class_getInstanceMethod(self,@selector(sx222_profileEdgePan:));
        Method replacement=class_getInstanceMethod(self,@selector(sx225_profileEdgePan:));
        if(target&&replacement){
            class_replaceMethod(self,@selector(sx222_profileEdgePan:),method_getImplementation(replacement),method_getTypeEncoding(target));
        }
    });
}

- (void)sx225_profileEdgePan:(UIPanGestureRecognizer *)gesture {
    UIView *moving=self.navigationController.view?:self.view;
    CGFloat width=MAX(moving.bounds.size.width,UIScreen.mainScreen.bounds.size.width);
    CGPoint translation=[gesture translationInView:moving];
    CGFloat x=MAX(0,MIN(width,translation.x));

    if(gesture.state==UIGestureRecognizerStateBegan){
        moving.layer.shadowColor=UIColor.blackColor.CGColor;
        moving.layer.shadowOpacity=.20;
        moving.layer.shadowRadius=8;
        moving.layer.shadowOffset=CGSizeMake(-3,0);
    } else if(gesture.state==UIGestureRecognizerStateChanged){
        moving.transform=CGAffineTransformMakeTranslation(x,0);
    } else if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled||gesture.state==UIGestureRecognizerStateFailed){
        CGFloat velocity=[gesture velocityInView:moving].x;
        CGFloat progress=x/MAX(width,1);
        BOOL finish=(gesture.state==UIGestureRecognizerStateEnded)&&((progress>=.30)||(velocity>600));
        if(finish){
            NSTimeInterval duration=velocity>900?.10:.18;
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                moving.transform=CGAffineTransformMakeTranslation(width,0);
            } completion:^(BOOL finished){
                moving.layer.shadowOpacity=0;
                UIViewController *presented=self.navigationController?:self;
                [presented dismissViewControllerAnimated:NO completion:^{
                    moving.transform=CGAffineTransformIdentity;
                }];
            }];
        } else {
            [UIView animateWithDuration:.20 delay:0 usingSpringWithDamping:.92 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                moving.transform=CGAffineTransformIdentity;
            } completion:^(BOOL finished){ moving.layer.shadowOpacity=0; }];
        }
    }
}

@end
