#import "NativeProfileViewController.h"
#import <objc/runtime.h>

static void (*SX280PreviousProfileTabTappedIMP)(id, SEL, UIButton *) = NULL;
static void (*SX280PreviousProfileTabSwipedIMP)(id, SEL, UISwipeGestureRecognizer *) = NULL;

static UITableView *SX280ProfileTable(NativeProfileViewController *profile) {
    UIScrollView *scroll = nil;
    @try { scroll = [profile valueForKey:@"scrollView"]; }
    @catch (__unused NSException *exception) {}
    return [scroll isKindOfClass:UITableView.class] ? (UITableView *)scroll : nil;
}

static void SX280ReloadProfileTable(NativeProfileViewController *profile) {
    UITableView *table = SX280ProfileTable(profile);
    if (!table) return;
    [table reloadData];
}

static void SX280ProfileTabTapped(id selfObject, SEL _cmd, UIButton *sender) {
    if (SX280PreviousProfileTabTappedIMP) SX280PreviousProfileTabTappedIMP(selfObject, _cmd, sender);
    SX280ReloadProfileTable((NativeProfileViewController *)selfObject);
}

static void SX280ProfileTabSwiped(id selfObject, SEL _cmd, UISwipeGestureRecognizer *gesture) {
    if (SX280PreviousProfileTabSwipedIMP) SX280PreviousProfileTabSwipedIMP(selfObject, _cmd, gesture);
    SX280ReloadProfileTable((NativeProfileViewController *)selfObject);
}

@implementation NativeProfileViewController (NativeProfileTableTabReload280)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = self;

        Method tapped = class_getInstanceMethod(cls, @selector(profileTabTapped:));
        if (tapped) {
            SX280PreviousProfileTabTappedIMP = (void (*)(id, SEL, UIButton *))method_getImplementation(tapped);
            class_replaceMethod(cls,
                                @selector(profileTabTapped:),
                                (IMP)SX280ProfileTabTapped,
                                method_getTypeEncoding(tapped));
        }

        Method swiped = class_getInstanceMethod(cls, @selector(profileTabSwiped:));
        if (swiped) {
            SX280PreviousProfileTabSwipedIMP = (void (*)(id, SEL, UISwipeGestureRecognizer *))method_getImplementation(swiped);
            class_replaceMethod(cls,
                                @selector(profileTabSwiped:),
                                (IMP)SX280ProfileTabSwiped,
                                method_getTypeEncoding(swiped));
        }
    });
}

@end
