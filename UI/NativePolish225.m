#import "NativeDrawerViewController.h"
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
                // Keep the outgoing profile offscreen until dismissal completes.
                // Resetting to identity here caused a one-frame flash of the profile.
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

@implementation NativeDrawerViewController (NativePolish225)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original=class_getInstanceMethod(self,@selector(viewDidLayoutSubviews));
        Method replacement=class_getInstanceMethod(self,@selector(sx225_viewDidLayoutSubviews));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx225_viewDidLayoutSubviews {
    [self sx225_viewDidLayoutSubviews];

    UITableView *table=nil;
    @try { table=[self valueForKey:@"tableView"]; } @catch(__unused NSException *exception) {}
    if(![table isKindOfClass:UITableView.class])return;
    UIView *header=table.tableHeaderView;
    if(!header)return;

    CGFloat width=table.bounds.size.width;
    if(width<=0)return;
    CGRect hf=header.frame;
    if(fabs(hf.size.width-width)>.5){
        hf.size.width=width;
        header.frame=hf;
        table.tableHeaderView=header;
    }

    UIButton *addButton=nil;
    NSMutableArray<UIButton *> *accountButtons=[NSMutableArray array];
    NSMutableArray<UIImageView *> *accountImages=[NSMutableArray array];

    for(UIView *sub in header.subviews){
        if([sub isKindOfClass:UIButton.class]){
            UIButton *button=(UIButton *)sub;
            NSString *label=button.accessibilityLabel?:@"";
            if([label isEqualToString:@"アカウントを追加"])addButton=button;
            else if([label hasSuffix:@" に切り替える"])[accountButtons addObject:button];
        } else if([sub isKindOfClass:UIImageView.class]){
            UIImageView *image=(UIImageView *)sub;
            if(fabs(image.bounds.size.width-34.0)<1.0&&fabs(image.bounds.size.height-34.0)<1.0){
                [accountImages addObject:image];
            }
        } else if([sub isKindOfClass:UILabel.class]){
            CGRect f=sub.frame;
            if(f.origin.x==18){ f.size.width=MAX(0,width-36); sub.frame=f; }
        }
    }

    if(addButton){
        CGRect f=addButton.frame;
        f.origin.x=MAX(18,width-54);
        addButton.frame=f;
    }

    [accountButtons sortUsingComparator:^NSComparisonResult(UIButton *a,UIButton *b){
        return a.frame.origin.x>b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;
    }];
    [accountImages sortUsingComparator:^NSComparisonResult(UIImageView *a,UIImageView *b){
        return a.frame.origin.x>b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;
    }];

    for(NSUInteger i=0;i<accountButtons.count;i++){
        UIButton *button=accountButtons[i];
        CGRect f=button.frame;
        f.origin.x=MAX(18,width-101-(CGFloat)i*42.0);
        button.frame=f;
    }
    for(NSUInteger i=0;i<accountImages.count;i++){
        UIImageView *image=accountImages[i];
        CGRect f=image.frame;
        f.origin.x=MAX(23,width-96-(CGFloat)i*42.0);
        image.frame=f;
    }
}

@end
