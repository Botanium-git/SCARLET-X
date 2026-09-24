#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Browser/BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"

static const void *SXQuickLogButtonKey = &SXQuickLogButtonKey;

@implementation BrowserViewController (QuickLogExport)

- (void)sx_installQuickLogButton {
    if (objc_getAssociatedObject(self, SXQuickLogButtonKey)) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.88];
    button.tintColor = UIColor.labelColor;
    button.layer.cornerRadius = 20.0;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = @"診断ログを出力";
    [button addTarget:self action:@selector(sx_exportDiagnostics:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:40.0],
        [button.heightAnchor constraintEqualToConstant:40.0],
        [button.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-10.0],
        [button.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0]
    ]];
    objc_setAssociatedObject(self, SXQuickLogButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sx_exportDiagnostics:(UIButton *)sender {
    NSArray *entries = DiagnosticsStore.shared.diagnosticEntries ?: @[];
    NSDictionary *payload = @{
        @"format": @"ScarletXLog",
        @"version": @2,
        @"type": @"diagnostics",
        @"exportedAt": @([[NSDate date] timeIntervalSince1970]),
        @"appVersion": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        @"build": NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"",
        @"entries": entries
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) return;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *name = [NSString stringWithFormat:@"ScarletX_DiagnosticLog_%@.json", [formatter stringFromDate:[NSDate date]]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    if (![data writeToURL:url options:NSDataWritingAtomic error:&error]) return;
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.sourceView = sender;
    share.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:share animated:YES completion:nil];
}

@end
