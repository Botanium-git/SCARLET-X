#import "NativeDrawerViewController.h"
#import "NativeProfileViewController.h"
#import "../Browser/BrowserViewController.h"
#import <objc/runtime.h>

@interface BrowserViewController (NativeGestures224Private) <UIGestureRecognizerDelegate>
- (BOOL)sx222_isTimelineVisible;
- (void)sx222_timelineEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture;
@end

@interface NativeProfileViewController (NativeGestures224Private) <UIGestureRecognizerDelegate>
- (void)sx222_profileEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture;
@end

@implementation NativeDrawerViewController (NativeGestures224)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method replacement=class_getInstanceMethod(self,@selector(sx224_drawerViewDidLoad));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx224_drawerViewDidLoad {
    [self sx224_drawerViewDidLoad];

    UIView *panel=nil;
    NSLayoutConstraint *leading=nil;
    @try {
        panel=[self valueForKey:@"panelView"];
        leading=[self valueForKey:@"panelLeadingConstraint"];
    } @catch(__unused NSException *exception) {}
    if(![panel isKindOfClass:UIView.class])return;

    CGFloat width=MIN(320.0,UIScreen.mainScreen.bounds.size.width*.82);
    for(NSLayoutConstraint *constraint in panel.constraints){
        if(constraint.firstItem==panel&&constraint.firstAttribute==NSLayoutAttributeWidth){
            constraint.constant=width;
        }
    }
    if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=-width;
    [self.view layoutIfNeeded];
}

@end

@implementation BrowserViewController (NativeGestures224)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method replacement=class_getInstanceMethod(self,@selector(sx224_browserViewDidLoad));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx224_browserViewDidLoad {
    [self sx224_browserViewDidLoad];

    for(UIGestureRecognizer *candidate in [self.view.gestureRecognizers copy]){
        if([candidate isKindOfClass:UIScreenEdgePanGestureRecognizer.class]){
            [self.view removeGestureRecognizer:candidate];
        }
    }

    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(sx224_timelinePan:)];
    pan.delegate=(id<UIGestureRecognizerDelegate>)self;
    pan.cancelsTouchesInView=NO;
    pan.maximumNumberOfTouches=1;
    [self.view addGestureRecognizer:pan];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if(![gesture isKindOfClass:UIPanGestureRecognizer.class])return YES;
    if(![self sx222_isTimelineVisible])return NO;
    UIPanGestureRecognizer *pan=(UIPanGestureRecognizer *)gesture;
    CGPoint velocity=[pan velocityInView:self.view];
    if(velocity.x<=80.0)return NO;
    if(fabs(velocity.x)<fabs(velocity.y)*1.15)return NO;
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)sx224_timelinePan:(UIPanGestureRecognizer *)gesture {
    [self sx222_timelineEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture];
}

@end

@implementation NativeProfileViewController (NativeGestures224)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method replacement=class_getInstanceMethod(self,@selector(sx224_profileViewDidLoad));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx224_profileViewDidLoad {
    [self sx224_profileViewDidLoad];

    for(UIGestureRecognizer *candidate in [self.view.gestureRecognizers copy]){
        if([candidate isKindOfClass:UIScreenEdgePanGestureRecognizer.class]){
            [self.view removeGestureRecognizer:candidate];
        }
    }

    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(sx224_profilePan:)];
    pan.delegate=(id<UIGestureRecognizerDelegate>)self;
    pan.cancelsTouchesInView=NO;
    pan.maximumNumberOfTouches=1;
    [self.view addGestureRecognizer:pan];

    UIScrollView *scroll=nil;
    @try { scroll=[self valueForKey:@"scrollView"]; } @catch(__unused NSException *exception) {}
    if([scroll isKindOfClass:UIScrollView.class]){
        for(UIGestureRecognizer *candidate in scroll.gestureRecognizers){
            if(![candidate isKindOfClass:UISwipeGestureRecognizer.class])continue;
            UISwipeGestureRecognizer *swipe=(UISwipeGestureRecognizer *)candidate;
            if(swipe.direction==UISwipeGestureRecognizerDirectionRight){
                [swipe requireGestureRecognizerToFail:pan];
            }
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if(![gesture isKindOfClass:UIPanGestureRecognizer.class])return YES;
    UIPanGestureRecognizer *pan=(UIPanGestureRecognizer *)gesture;
    CGPoint location=[pan locationInView:self.view];
    CGFloat allowed=MAX(72.0,self.view.bounds.size.width*.28);
    if(location.x>allowed)return NO;
    CGPoint velocity=[pan velocityInView:self.view];
    if(velocity.x<=80.0)return NO;
    if(fabs(velocity.x)<fabs(velocity.y)*1.15)return NO;
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)sx224_profilePan:(UIPanGestureRecognizer *)gesture {
    [self sx222_profileEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture];
}

@end
