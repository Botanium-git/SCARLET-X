#import "NativeProfileViewController.h"
#import "../Browser/BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeGestures221Private)
- (void)openNativeDrawer;
@end

@implementation BrowserViewController (NativeGestures221)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method replacement=class_getInstanceMethod(self,@selector(sx221_viewDidLoad));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx221_viewDidLoad {
    [self sx221_viewDidLoad];

    UIScreenEdgePanGestureRecognizer *edge=[[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(sx221_timelineEdgePan:)];
    edge.edges=UIRectEdgeLeft;
    edge.cancelsTouchesInView=NO;
    [self.view addGestureRecognizer:edge];
}

- (void)sx221_timelineEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateEnded)return;

    CGPoint translation=[gesture translationInView:self.view];
    CGPoint velocity=[gesture velocityInView:self.view];
    if(translation.x<55.0&&velocity.x<450.0)return;

    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    NSString *path=[webView isKindOfClass:WKWebView.class]?webView.URL.path:@"";
    BOOL isTimeline=(path.length==0||[path isEqualToString:@"/"]||[path isEqualToString:@"/home"]);
    if(!isTimeline)return;

    [self openNativeDrawer];
}

@end

@implementation NativeProfileViewController (NativeGestures221)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method loadOriginal=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method loadReplacement=class_getInstanceMethod(self,@selector(sx221_profileViewDidLoad));
        if(loadOriginal&&loadReplacement)method_exchangeImplementations(loadOriginal,loadReplacement);

        Method swipeOriginal=class_getInstanceMethod(self,@selector(profileTabSwiped:));
        Method swipeReplacement=class_getInstanceMethod(self,@selector(sx221_profileTabSwiped:));
        if(swipeOriginal&&swipeReplacement)method_exchangeImplementations(swipeOriginal,swipeReplacement);

        Method tapOriginal=class_getInstanceMethod(self,@selector(profileTabTapped:));
        Method tapReplacement=class_getInstanceMethod(self,@selector(sx221_profileTabTapped:));
        if(tapOriginal&&tapReplacement)method_exchangeImplementations(tapOriginal,tapReplacement);
    });
}

- (void)sx221_profileViewDidLoad {
    [self sx221_profileViewDidLoad];

    // X-style profile navigation relies on the edge swipe rather than the old close button.
    self.navigationItem.leftBarButtonItem=nil;
    self.navigationItem.hidesBackButton=YES;

    UIScreenEdgePanGestureRecognizer *edge=[[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(sx221_profileEdgePan:)];
    edge.edges=UIRectEdgeLeft;
    edge.cancelsTouchesInView=NO;
    [self.view addGestureRecognizer:edge];

    UIScrollView *scroll=nil;
    @try { scroll=[self valueForKey:@"scrollView"]; } @catch(__unused NSException *exception) {}
    if([scroll isKindOfClass:UIScrollView.class]){
        for(UIGestureRecognizer *candidate in scroll.gestureRecognizers){
            if(![candidate isKindOfClass:UISwipeGestureRecognizer.class])continue;
            UISwipeGestureRecognizer *swipe=(UISwipeGestureRecognizer *)candidate;
            if(swipe.direction==UISwipeGestureRecognizerDirectionRight){
                [swipe requireGestureRecognizerToFail:edge];
            }
        }
    }
}

- (void)sx221_profileEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateEnded)return;
    CGPoint translation=[gesture translationInView:self.view];
    CGPoint velocity=[gesture velocityInView:self.view];
    if(translation.x<55.0&&velocity.x<450.0)return;

    if([self respondsToSelector:@selector(closeTapped:)]){
        [self performSelector:@selector(closeTapped:) withObject:nil];
    }
}

- (void)sx221_addTabTransitionForward:(BOOL)forward {
    CATransition *transition=[CATransition animation];
    transition.duration=.20;
    transition.type=kCATransitionPush;
    transition.subtype=forward?kCATransitionFromRight:kCATransitionFromLeft;
    transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.view.layer addAnimation:transition forKey:@"sx221-profile-tab"];
}

- (void)sx221_profileTabSwiped:(UISwipeGestureRecognizer *)gesture {
    NSInteger current=0;
    @try { current=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}
    NSInteger next=current;
    if(gesture.direction==UISwipeGestureRecognizerDirectionLeft)next=MIN(3,current+1);
    else if(gesture.direction==UISwipeGestureRecognizerDirectionRight)next=MAX(0,current-1);
    if(next==current)return;

    [self sx221_addTabTransitionForward:(next>current)];
    [self sx221_profileTabSwiped:gesture];
}

- (void)sx221_profileTabTapped:(UIButton *)sender {
    NSInteger current=0;
    @try { current=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}
    NSInteger next=sender.tag;
    if(next<0||next>3||next==current)return;

    [self sx221_addTabTransitionForward:(next>current)];
    [self sx221_profileTabTapped:sender];
}

@end
