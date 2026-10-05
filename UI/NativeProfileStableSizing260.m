#import "NativeProfileViewController.h"
#import <objc/runtime.h>
#import <math.h>

@interface NativeProfileViewController (NativeProfileStableSizing260Private)
- (UIView *)postViewForPost:(NSDictionary *)post;
@end

@interface SX260StablePostCell : UITableViewCell
@end

@implementation SX260StablePostCell

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
       withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority
             verticalFittingPriority:(UILayoutPriority)verticalFittingPriority {
    CGFloat width = targetSize.width;
    if (!isfinite(width) || width <= 0.0) width = CGRectGetWidth(self.bounds);
    if (!isfinite(width) || width <= 0.0) {
        return [super systemLayoutSizeFittingSize:targetSize
                   withHorizontalFittingPriority:horizontalFittingPriority
                         verticalFittingPriority:verticalFittingPriority];
    }

    CGRect bounds = self.contentView.bounds;
    bounds.size.width = width;
    self.contentView.bounds = bounds;
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    CGSize measured = [self.contentView
        systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired
        verticalFittingPriority:UILayoutPriorityFittingSizeLevel];

    if (!isfinite(measured.height) || measured.height <= 0.0) {
        return [super systemLayoutSizeFittingSize:targetSize
                   withHorizontalFittingPriority:horizontalFittingPriority
                         verticalFittingPriority:verticalFittingPriority];
    }

    return CGSizeMake(width, ceil(measured.height));
}

@end

typedef UITableViewCell *(*SX260PostCellIMP)(id, SEL, UITableView *, NSDictionary *);
static SX260PostCellIMP SX260PreviousPostCellIMP = NULL;

static UITableViewCell *SX260PostCell(id selfObject,
                                     SEL _cmd,
                                     UITableView *tableView,
                                     NSDictionary *post) {
    NativeProfileViewController *profile = nil;
    @try { profile = [selfObject valueForKey:@"profile"]; }
    @catch (__unused NSException *exception) {}

    if (![profile isKindOfClass:NativeProfileViewController.class]) {
        return SX260PreviousPostCellIMP
            ? SX260PreviousPostCellIMP(selfObject, _cmd, tableView, post)
            : nil;
    }

    static NSString *identifier = @"SX260StablePostCell";
    SX260StablePostCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[SX260StablePostCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:identifier];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;
    cell.contentView.backgroundColor = UIColor.systemBackgroundColor;

    for (UIView *subview in [cell.contentView.subviews copy]) {
        [subview removeFromSuperview];
    }

    UIView *postView = [profile postViewForPost:post];
    if (![postView isKindOfClass:UIView.class]) {
        return SX260PreviousPostCellIMP
            ? SX260PreviousPostCellIMP(selfObject, _cmd, tableView, post)
            : cell;
    }

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

@interface SX260StableSizingInstaller : NSObject
@end

@implementation SX260StableSizingInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL selector = NSSelectorFromString(@"postCellForTable:post:");
        Method method = class_getInstanceMethod(adapterClass, selector);
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)SX260PostCell) return;

        SX260PreviousPostCellIMP = (SX260PostCellIMP)current;
        class_replaceMethod(adapterClass,
                            selector,
                            (IMP)SX260PostCell,
                            method_getTypeEncoding(method));
    });
}

@end
