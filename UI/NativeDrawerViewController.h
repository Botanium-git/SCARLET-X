#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NativeDrawerViewController;

@protocol NativeDrawerViewControllerDelegate <NSObject>
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path;
- (void)nativeDrawerDidSelectScarletSettings:(NativeDrawerViewController *)drawer;
@end

@interface NativeDrawerViewController : UIViewController
@property(nonatomic,weak) id<NativeDrawerViewControllerDelegate> delegate;
- (void)presentInParent:(UIViewController *)parent;
- (void)dismissAnimated:(BOOL)animated;
@end

NS_ASSUME_NONNULL_END
