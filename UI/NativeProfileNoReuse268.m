#import "NativeProfileViewController.h"
#import <objc/runtime.h>

@interface NativeProfileViewController (SX268NoReusePrivate)
- (UIView *)postViewForPost:(NSDictionary *)post;
@end

static UITableViewCell *SX268PostCellNoReuse(id selfObject,
                                            SEL _cmd,
                                            UITableView *tableView,
                                            NSDictionary *post) {
    NativeProfileViewController *profile = nil;
    @try { profile = [selfObject valueForKey:@"profile"]; }
    @catch (__unused NSException *exception) {}

    if (![profile isKindOfClass:NativeProfileViewController.class]) return nil;

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;

    UIView *postView = [profile postViewForPost:post];
    if (![postView isKindOfClass:UIView.class]) return cell;

    postView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:postView];
    [NSLayoutConstraint activateConstraints:@[
        [postView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [postView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [postView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [postView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];
    return cell;
}

@interface SX268NoReuseInstaller : NSObject
@end

@implementation SX268NoReuseInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL selector = NSSelectorFromString(@"postCellForTable:post:");
        Method method = class_getInstanceMethod(adapterClass, selector);
        if (!method) return;

        class_replaceMethod(adapterClass,
                            selector,
                            (IMP)SX268PostCellNoReuse,
                            method_getTypeEncoding(method));
    });
}

@end
