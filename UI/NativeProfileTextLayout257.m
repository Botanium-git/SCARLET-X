#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITableViewCell *(*SX257PreviousPostCellIMP)(id, SEL, UITableView *, NSDictionary *) = NULL;

static void SX257StabilizeMultilineLabels(UIView *view) {
    if (![view isKindOfClass:UIView.class]) return;

    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.numberOfLines == 0) {
            label.lineBreakMode = NSLineBreakByWordWrapping;
            [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisVertical];
            [label setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                     forAxis:UILayoutConstraintAxisVertical];
        }
    }

    for (UIView *subview in view.subviews) {
        SX257StabilizeMultilineLabels(subview);
    }
}

static UITableViewCell *SX257PostCell(id selfObject,
                                     SEL _cmd,
                                     UITableView *tableView,
                                     NSDictionary *post) {
    UITableViewCell *cell = SX257PreviousPostCellIMP
        ? SX257PreviousPostCellIMP(selfObject, _cmd, tableView, post)
        : nil;

    if ([cell isKindOfClass:UITableViewCell.class]) {
        SX257StabilizeMultilineLabels(cell.contentView);
    }
    return cell;
}

@interface SX257TextLayoutInstaller : NSObject
@end

@implementation SX257TextLayoutInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL selector = NSSelectorFromString(@"postCellForTable:post:");
        Method method = class_getInstanceMethod(adapterClass, selector);
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)SX257PostCell) return;

        SX257PreviousPostCellIMP = (UITableViewCell *(*)(id, SEL, UITableView *, NSDictionary *))current;
        class_replaceMethod(adapterClass,
                            selector,
                            (IMP)SX257PostCell,
                            method_getTypeEncoding(method));
    });
}

@end
