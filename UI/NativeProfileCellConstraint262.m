#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITableViewCell *(*SX262PreviousPostCellIMP)(id, SEL, UITableView *, NSDictionary *) = NULL;

static UITableViewCell *SX262PostCell(id selfObject,
                                     SEL _cmd,
                                     UITableView *tableView,
                                     NSDictionary *post) {
    UITableViewCell *cell = SX262PreviousPostCellIMP
        ? SX262PreviousPostCellIMP(selfObject, _cmd, tableView, post)
        : nil;
    if (![cell isKindOfClass:UITableViewCell.class]) return cell;

    UIView *contentView = cell.contentView;
    for (NSLayoutConstraint *constraint in [contentView.constraints copy]) {
        BOOL postToContentBottom =
            constraint.firstAttribute == NSLayoutAttributeBottom &&
            constraint.secondAttribute == NSLayoutAttributeBottom &&
            ((constraint.firstItem != contentView && constraint.secondItem == contentView) ||
             (constraint.secondItem != contentView && constraint.firstItem == contentView));

        if (postToContentBottom && constraint.relation == NSLayoutRelationEqual && constraint.priority == UILayoutPriorityRequired) {
            constraint.priority = 999.0;
        }
    }
    return cell;
}

@interface SX262CellConstraintInstaller : NSObject
@end

@implementation SX262CellConstraintInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL selector = NSSelectorFromString(@"postCellForTable:post:");
        Method method = class_getInstanceMethod(adapterClass, selector);
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)SX262PostCell) return;

        SX262PreviousPostCellIMP = (UITableViewCell *(*)(id, SEL, UITableView *, NSDictionary *))current;
        class_replaceMethod(adapterClass,
                            selector,
                            (IMP)SX262PostCell,
                            method_getTypeEncoding(method));
    });
}

@end
