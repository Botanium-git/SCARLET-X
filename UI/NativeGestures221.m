#import "NativeProfileViewController.h"
#import "NativeDrawerViewController.h"
#import "../Browser/BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char SX222DrawerGestureActiveKey;
static char SX222DrawerGestureDrawerKey;
static char SX222DrawerGestureWidthKey;

@interface BrowserViewController (NativeGestures222Private) <NativeDrawerViewControllerDelegate>
- (NSDictionary *)sx218_persistedDrawerData;
- (void)sx217_prefetchDrawerData;
- (NativeProfileViewController *)sx217_presentProfileFromRight:(NSDictionary *)profileData;
@end

@implementation BrowserViewController (NativeGestures222)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method replacement=class_getInstanceMethod(self,@selector(sx222_viewDidLoad));
        if(original&&replacement)method_exchangeImplementations(original,replacement);

        Method presentTarget=class_getInstanceMethod(self,@selector(sx217_presentProfileFromRight:));
        Method presentReplacement=class_getInstanceMethod(self,@selector(sx222_presentProfileFromRight:));
        if(presentTarget&&presentReplacement){
            class_replaceMethod(self,@selector(sx217_presentProfileFromRight:),method_getImplementation(presentReplacement),method_getTypeEncoding(presentTarget));
        }
    });
}

- (void)sx222_viewDidLoad {
    [self sx222_viewDidLoad];

    UIScreenEdgePanGestureRecognizer *edge=[[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(sx222_timelineEdgePan:)];
    edge.edges=UIRectEdgeLeft;
    edge.cancelsTouchesInView=NO;
    [self.view addGestureRecognizer:edge];
}

- (BOOL)sx222_isTimelineVisible {
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    NSString *path=[webView isKindOfClass:WKWebView.class]?webView.URL.path:@"";
    return path.length==0||[path isEqualToString:@"/"]||[path isEqualToString:@"/home"];
}

- (NativeDrawerViewController *)sx222_beginInteractiveDrawer {
    NativeDrawerViewController *existing=nil;
    @try { existing=[self valueForKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
    if([existing isKindOfClass:NativeDrawerViewController.class]&&existing.parentViewController)return existing;

    NSDictionary *cached=nil;
    if([self respondsToSelector:@selector(sx218_persistedDrawerData)])cached=[self sx218_persistedDrawerData];

    NativeDrawerViewController *drawer=[NativeDrawerViewController new];
    drawer.delegate=(id<NativeDrawerViewControllerDelegate>)self;
    drawer.profileData=[cached isKindOfClass:NSDictionary.class]?cached:@{};
    @try { [self setValue:drawer forKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}

    [self addChildViewController:drawer];
    drawer.view.frame=self.view.bounds;
    drawer.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:drawer.view];
    [drawer didMoveToParentViewController:self];
    [drawer.view layoutIfNeeded];

    UIView *panel=nil,*dimming=nil;
    NSLayoutConstraint *leading=nil;
    @try {
        panel=[drawer valueForKey:@"panelView"];
        dimming=[drawer valueForKey:@"dimmingView"];
        leading=[drawer valueForKey:@"panelLeadingConstraint"];
    } @catch(__unused NSException *exception) {}
    CGFloat width=[panel isKindOfClass:UIView.class]&&panel.bounds.size.width>0?panel.bounds.size.width:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86);
    if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=-width;
    if([dimming isKindOfClass:UIView.class])dimming.alpha=0;
    [drawer.view layoutIfNeeded];

    objc_setAssociatedObject(self,&SX222DrawerGestureDrawerKey,drawer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self,&SX222DrawerGestureWidthKey,@(width),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return drawer;
}

- (void)sx222_finishInteractiveDrawer:(NativeDrawerViewController *)drawer opened:(BOOL)opened velocity:(CGFloat)velocity {
    UIView *panel=nil,*dimming=nil;
    NSLayoutConstraint *leading=nil;
    @try {
        panel=[drawer valueForKey:@"panelView"];
        dimming=[drawer valueForKey:@"dimmingView"];
        leading=[drawer valueForKey:@"panelLeadingConstraint"];
    } @catch(__unused NSException *exception) {}
    CGFloat width=[objc_getAssociatedObject(self,&SX222DrawerGestureWidthKey) doubleValue];
    if(width<=0)width=[panel isKindOfClass:UIView.class]&&panel.bounds.size.width>0?panel.bounds.size.width:MIN(340.0,UIScreen.mainScreen.bounds.size.width*.86);

    CGFloat current=[leading isKindOfClass:NSLayoutConstraint.class]?leading.constant:-width;
    CGFloat progress=MAX(0,MIN(1,(current+width)/MAX(width,1)));
    CGFloat remaining=opened?(1-progress):progress;
    NSTimeInterval duration=MAX(.10,MIN(.22,.10+.12*remaining));
    if(fabs(velocity)>900)duration=.10;

    if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=opened?0:-width;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if([dimming isKindOfClass:UIView.class])dimming.alpha=opened?1:0;
        [drawer.view layoutIfNeeded];
    } completion:^(BOOL finished){
        if(!opened){
            [drawer willMoveToParentViewController:nil];
            [drawer.view removeFromSuperview];
            [drawer removeFromParentViewController];
            @try { [self setValue:nil forKey:@"nativeDrawer"]; } @catch(__unused NSException *exception) {}
        } else if([self respondsToSelector:@selector(sx217_prefetchDrawerData)]) {
            [self sx217_prefetchDrawerData];
        }
    }];
}

- (void)sx222_timelineEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan){
        BOOL active=[self sx222_isTimelineVisible];
        objc_setAssociatedObject(self,&SX222DrawerGestureActiveKey,@(active),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(!active)return;
        [self sx222_beginInteractiveDrawer];
    }

    BOOL active=[objc_getAssociatedObject(self,&SX222DrawerGestureActiveKey) boolValue];
    if(!active)return;
    NativeDrawerViewController *drawer=objc_getAssociatedObject(self,&SX222DrawerGestureDrawerKey);
    if(![drawer isKindOfClass:NativeDrawerViewController.class])return;

    UIView *dimming=nil;
    NSLayoutConstraint *leading=nil;
    @try { dimming=[drawer valueForKey:@"dimmingView"]; leading=[drawer valueForKey:@"panelLeadingConstraint"]; } @catch(__unused NSException *exception) {}
    CGFloat width=[objc_getAssociatedObject(self,&SX222DrawerGestureWidthKey) doubleValue];
    if(width<=0)return;

    CGPoint translation=[gesture translationInView:self.view];
    CGFloat progress=MAX(0,MIN(1,translation.x/width));
    if(gesture.state==UIGestureRecognizerStateChanged){
        if([leading isKindOfClass:NSLayoutConstraint.class])leading.constant=-width+(progress*width);
        if([dimming isKindOfClass:UIView.class])dimming.alpha=progress;
        [drawer.view layoutIfNeeded];
        return;
    }

    if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled||gesture.state==UIGestureRecognizerStateFailed){
        CGFloat velocity=[gesture velocityInView:self.view].x;
        BOOL opened=(gesture.state==UIGestureRecognizerStateEnded)&&((progress>=.34)||(velocity>520));
        [self sx222_finishInteractiveDrawer:drawer opened:opened velocity:velocity];
        objc_setAssociatedObject(self,&SX222DrawerGestureActiveKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,&SX222DrawerGestureDrawerKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NativeProfileViewController *)sx222_presentProfileFromRight:(NSDictionary *)profileData {
    NativeProfileViewController *profile=[NativeProfileViewController new];
    profile.profileData=profileData?:@{};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:profile];
    nav.navigationBarHidden=YES;
    nav.modalPresentationStyle=UIModalPresentationOverFullScreen;
    nav.view.backgroundColor=UIColor.systemBackgroundColor;

    CGFloat width=MAX(self.view.bounds.size.width,UIScreen.mainScreen.bounds.size.width);
    nav.view.transform=CGAffineTransformMakeTranslation(width,0);
    [self presentViewController:nav animated:NO completion:^{
        [UIView animateWithDuration:.20 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            nav.view.transform=CGAffineTransformIdentity;
        } completion:nil];
    }];
    return profile;
}

@end

static CGRect SX222TabContentRegion(NativeProfileViewController *controller) {
    CGFloat maxY=0;
    NSMutableArray<UIView *> *queue=[NSMutableArray arrayWithObject:controller.view];
    NSSet *titles=[NSSet setWithArray:@[@"ポスト",@"返信",@"ハイライト",@"メディア"]];
    while(queue.count){
        UIView *view=queue.firstObject;
        [queue removeObjectAtIndex:0];
        if([view isKindOfClass:UIButton.class]){
            NSString *title=[(UIButton *)view titleForState:UIControlStateNormal];
            if([titles containsObject:title]){
                CGRect r=[view convertRect:view.bounds toView:controller.view];
                maxY=MAX(maxY,CGRectGetMaxY(r));
            }
        }
        for(UIView *sub in view.subviews)[queue addObject:sub];
    }
    CGFloat top=maxY>0?maxY:controller.view.bounds.size.height*.55;
    top=MIN(MAX(top,0),controller.view.bounds.size.height);
    return CGRectMake(0,top,controller.view.bounds.size.width,MAX(0,controller.view.bounds.size.height-top));
}

@implementation NativeProfileViewController (NativeGestures222)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method loadOriginal=class_getInstanceMethod(self,@selector(viewDidLoad));
        Method loadReplacement=class_getInstanceMethod(self,@selector(sx222_profileViewDidLoad));
        if(loadOriginal&&loadReplacement)method_exchangeImplementations(loadOriginal,loadReplacement);

        Method swipeOriginal=class_getInstanceMethod(self,@selector(profileTabSwiped:));
        Method swipeReplacement=class_getInstanceMethod(self,@selector(sx222_profileTabSwiped:));
        if(swipeOriginal&&swipeReplacement)method_exchangeImplementations(swipeOriginal,swipeReplacement);

        Method tapOriginal=class_getInstanceMethod(self,@selector(profileTabTapped:));
        Method tapReplacement=class_getInstanceMethod(self,@selector(sx222_profileTabTapped:));
        if(tapOriginal&&tapReplacement)method_exchangeImplementations(tapOriginal,tapReplacement);
    });
}

- (void)sx222_profileViewDidLoad {
    [self sx222_profileViewDidLoad];
    self.title=nil;
    self.navigationItem.title=nil;
    self.navigationItem.leftBarButtonItem=nil;
    self.navigationItem.rightBarButtonItem=nil;
    self.navigationController.navigationBarHidden=YES;

    UIScreenEdgePanGestureRecognizer *edge=[[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(sx222_profileEdgePan:)];
    edge.edges=UIRectEdgeLeft;
    edge.cancelsTouchesInView=NO;
    [self.view addGestureRecognizer:edge];

    UIScrollView *scroll=nil;
    @try { scroll=[self valueForKey:@"scrollView"]; } @catch(__unused NSException *exception) {}
    if([scroll isKindOfClass:UIScrollView.class]){
        for(UIGestureRecognizer *candidate in scroll.gestureRecognizers){
            if(![candidate isKindOfClass:UISwipeGestureRecognizer.class])continue;
            UISwipeGestureRecognizer *swipe=(UISwipeGestureRecognizer *)candidate;
            if(swipe.direction==UISwipeGestureRecognizerDirectionRight)[swipe requireGestureRecognizerToFail:edge];
        }
    }
}

- (void)sx222_profileEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
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
                moving.transform=CGAffineTransformIdentity;
                [(self.navigationController?:self) dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            [UIView animateWithDuration:.20 delay:0 usingSpringWithDamping:.92 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                moving.transform=CGAffineTransformIdentity;
            } completion:^(BOOL finished){ moving.layer.shadowOpacity=0; }];
        }
    }
}

- (void)sx222_animateTabRegionForward:(BOOL)forward change:(dispatch_block_t)change {
    [self.view layoutIfNeeded];
    CGRect region=SX222TabContentRegion(self);
    if(region.size.height<=1||region.size.width<=1){ if(change)change(); return; }

    UIView *oldSnapshot=[self.view resizableSnapshotViewFromRect:region afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
    if(change)change();
    [self.view layoutIfNeeded];
    UIView *newSnapshot=[self.view resizableSnapshotViewFromRect:region afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
    if(!oldSnapshot||!newSnapshot)return;

    oldSnapshot.frame=region;
    newSnapshot.frame=region;
    CGFloat width=region.size.width;
    newSnapshot.transform=CGAffineTransformMakeTranslation(forward?width:-width,0);
    [self.view addSubview:oldSnapshot];
    [self.view addSubview:newSnapshot];

    [UIView animateWithDuration:.22 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        oldSnapshot.transform=CGAffineTransformMakeTranslation(forward?-width*.28:width*.28,0);
        newSnapshot.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished){
        [oldSnapshot removeFromSuperview];
        [newSnapshot removeFromSuperview];
    }];
}

- (void)sx222_profileTabSwiped:(UISwipeGestureRecognizer *)gesture {
    NSInteger current=0;
    @try { current=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}
    NSInteger next=current;
    if(gesture.direction==UISwipeGestureRecognizerDirectionLeft)next=MIN(3,current+1);
    else if(gesture.direction==UISwipeGestureRecognizerDirectionRight)next=MAX(0,current-1);
    if(next==current)return;

    BOOL forward=next>current;
    [self sx222_animateTabRegionForward:forward change:^{ [self sx222_profileTabSwiped:gesture]; }];
}

- (void)sx222_profileTabTapped:(UIButton *)sender {
    NSInteger current=0;
    @try { current=[[self valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}
    NSInteger next=sender.tag;
    if(next<0||next>3||next==current)return;

    BOOL forward=next>current;
    [self sx222_animateTabRegionForward:forward change:^{ [self sx222_profileTabTapped:sender]; }];
}

@end
