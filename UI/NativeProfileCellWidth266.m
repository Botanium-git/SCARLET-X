#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITableViewCell *(*SX266PreviousPostCellIMP)(id, SEL, UITableView *, NSDictionary *) = NULL;

static UITableViewCell *SX266PostCell(id selfObject,
                                     SEL _cmd,
                                     UITableView *tableView,
                                     NSDictionary *post) {
    UITableViewCell *cell = SX266PreviousPostCellIMP
        ? SX266PreviousPostCellIMP(selfObject, _cmd, tableView, post)
        : nil;
    if (![cell isKindOfClass:UITableViewCell.class] || ![tableView isKindOfClass:UITableView.class]) return cell;

    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (width > 0.0) {
        CGRect cellBounds = cell.bounds;
        cellBounds.size.width = width;
        cell.bounds = cellBounds;

        CGRect contentBounds = cell.contentView.bounds;
        contentBounds.size.width = width;
        cell.contentView.bounds = contentBounds;

        [cell.contentView setNeedsLayout];
        [cell.contentView layoutIfNeeded];
    }

    return cell;
}

@interface SX266CellWidthInstaller : NSObject
@end

@implementation SX266CellWidthInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL selector = NSSelectorFromString(@"postCellForTable:post:");
        Method method = class_getInstanceMethod(adapterClass, selector);
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)SX266PostCell) return;

        SX266PreviousPostCellIMP = (UITableViewCell *(*)(id, SEL, UITableView *, NSDictionary *))current;
        class_replaceMethod(adapterClass,
                            selector,
                            (IMP)SX266PostCell,
                            method_getTypeEncoding(method));
    });
}

@end
