#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SXLogKind) {
    SXLogKindDiagnostics,
    SXLogKindErrors
};

@interface LogViewController : UITableViewController
- (instancetype)initWithLogKind:(SXLogKind)logKind;
@end
