#import "NativeProfileViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

@interface NativeProfileViewController (SX269MeasuredHeightPrivate)
- (UIView *)postViewForPost:(NSDictionary *)post;
@end

static char SX269HeightCacheKey;
static char SX269WidthKey;

static NSMutableDictionary<NSString *, NSNumber *> *SX269HeightCache(id adapter) {
    NSMutableDictionary *cache = objc_getAssociatedObject(adapter, &SX269HeightCacheKey);
    if (!cache) {
        cache = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(adapter, &SX269HeightCacheKey, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

static NSString *SX269StringValue(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    return @"";
}

static NSString *SX269PostKey(NSDictionary *post) {
    NSArray<NSString *> *idKeys = @[@"id", @"tweetId", @"tweetID", @"restId", @"rest_id", @"statusId", @"statusID"];
    for (NSString *key in idKeys) {
        NSString *value = SX269StringValue(post[key]);
        if (value.length) return [@"id:" stringByAppendingString:value];
    }

    NSString *author = SX269StringValue(post[@"authorHandle"]);
    NSString *created = SX269StringValue(post[@"createdAt"]);
    NSString *text = SX269StringValue(post[@"text"]);
    NSArray *media = [post[@"media"] isKindOfClass:NSArray.class] ? post[@"media"] : @[];
    NSString *legacyMedia = SX269StringValue(post[@"mediaURL"]);
    NSString *raw = [NSString stringWithFormat:@"%@|%@|%@|%lu|%@|%@",
                     author,
                     created,
                     text,
                     (unsigned long)media.count,
                     legacyMedia,
                     [post[@"isRepost"] respondsToSelector:@selector(boolValue)] && [post[@"isRepost"] boolValue] ? @"1" : @"0"];
    return [NSString stringWithFormat:@"fallback:%lu", (unsigned long)raw.hash];
}

static void SX269ResetCacheIfWidthChanged(id adapter, CGFloat width) {
    NSNumber *previous = objc_getAssociatedObject(adapter, &SX269WidthKey);
    if (!previous || fabs(previous.doubleValue - width) > 0.5) {
        [SX269HeightCache(adapter) removeAllObjects];
        objc_setAssociatedObject(adapter, &SX269WidthKey, @(width), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGFloat SX269MeasuredHeight(id adapter, UITableView *tableView, NSDictionary *post) {
    if (![tableView isKindOfClass:UITableView.class] || ![post isKindOfClass:NSDictionary.class]) return 240.0;

    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (width <= 0.0) return 240.0;
    SX269ResetCacheIfWidthChanged(adapter, width);

    NSString *key = SX269PostKey(post);
    NSNumber *cached = SX269HeightCache(adapter)[key];
    if (cached.doubleValue > 0.0) return cached.doubleValue;

    NativeProfileViewController *profile = nil;
    @try { profile = [adapter valueForKey:@"profile"]; }
    @catch (__unused NSException *exception) {}
    if (![profile isKindOfClass:NativeProfileViewController.class]) return 240.0;

    UIView *postView = [profile postViewForPost:post];
    if (![postView isKindOfClass:UIView.class]) return 240.0;

    postView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *widthConstraint = [postView.widthAnchor constraintEqualToConstant:width];
    widthConstraint.active = YES;

    CGSize measured = [postView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                              withHorizontalFittingPriority:UILayoutPriorityRequired
                                    verticalFittingPriority:UILayoutPriorityFittingSizeLevel];

    widthConstraint.active = NO;

    CGFloat height = ceil(measured.height);
    if (!isfinite(height) || height <= 0.0) return 240.0;

    SX269HeightCache(adapter)[key] = @(height);
    return height;
}

typedef CGFloat (*SX269HeightIMP)(id, SEL, UITableView *, NSIndexPath *);
static SX269HeightIMP SX269PreviousHeightIMP = NULL;
static SX269HeightIMP SX269PreviousEstimatedIMP = NULL;

static NSDictionary *SX269PostForIndexPath(id adapter, NSIndexPath *indexPath) {
    NSInteger tab = -1;
    NSDictionary *data = nil;
    NSArray *items = nil;

    SEL selectedTabSEL = NSSelectorFromString(@"selectedTab");
    if ([adapter respondsToSelector:selectedTabSEL]) {
        NSInteger (*msg)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
        tab = msg(adapter, selectedTabSEL);
    }

    SEL dataSEL = NSSelectorFromString(@"data");
    if ([adapter respondsToSelector:dataSEL]) {
        id (*msg)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        data = msg(adapter, dataSEL);
    }

    SEL itemsSEL = NSSelectorFromString(@"itemsForTab:data:");
    if ([adapter respondsToSelector:itemsSEL]) {
        id (*msg)(id, SEL, NSInteger, NSDictionary *) = (id (*)(id, SEL, NSInteger, NSDictionary *))objc_msgSend;
        items = msg(adapter, itemsSEL, tab, data ?: @{});
    }

    if (![items isKindOfClass:NSArray.class] || indexPath.row < 0 || (NSUInteger)indexPath.row >= items.count) return nil;
    id item = items[(NSUInteger)indexPath.row];
    return [item isKindOfClass:NSDictionary.class] ? item : nil;
}

static CGFloat SX269HeightForRow(id adapter, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    NSDictionary *post = SX269PostForIndexPath(adapter, indexPath);
    if (!post) {
        return SX269PreviousHeightIMP ? SX269PreviousHeightIMP(adapter, _cmd, tableView, indexPath) : 64.0;
    }
    return SX269MeasuredHeight(adapter, tableView, post);
}

static CGFloat SX269EstimatedHeightForRow(id adapter, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    NSDictionary *post = SX269PostForIndexPath(adapter, indexPath);
    if (!post) {
        return SX269PreviousEstimatedIMP ? SX269PreviousEstimatedIMP(adapter, _cmd, tableView, indexPath) : 64.0;
    }
    return SX269MeasuredHeight(adapter, tableView, post);
}

@interface SX269MeasuredHeightInstaller : NSObject
@end

@implementation SX269MeasuredHeightInstaller

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class adapterClass = NSClassFromString(@"SX251TimelineAdapter");
        if (!adapterClass) return;

        SEL heightSEL = NSSelectorFromString(@"tableView:heightForRowAtIndexPath:");
        Method heightMethod = class_getInstanceMethod(adapterClass, heightSEL);
        if (heightMethod) {
            IMP current = method_getImplementation(heightMethod);
            if (current != (IMP)SX269HeightForRow) {
                SX269PreviousHeightIMP = (SX269HeightIMP)current;
                class_replaceMethod(adapterClass, heightSEL, (IMP)SX269HeightForRow, method_getTypeEncoding(heightMethod));
            }
        }

        SEL estimatedSEL = NSSelectorFromString(@"tableView:estimatedHeightForRowAtIndexPath:");
        Method estimatedMethod = class_getInstanceMethod(adapterClass, estimatedSEL);
        if (estimatedMethod) {
            IMP current = method_getImplementation(estimatedMethod);
            if (current != (IMP)SX269EstimatedHeightForRow) {
                SX269PreviousEstimatedIMP = (SX269HeightIMP)current;
                class_replaceMethod(adapterClass, estimatedSEL, (IMP)SX269EstimatedHeightForRow, method_getTypeEncoding(estimatedMethod));
            }
        }
    });
}

@end
