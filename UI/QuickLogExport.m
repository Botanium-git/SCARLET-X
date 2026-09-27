#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
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

- (void)sx_shareDiagnostics:(UIButton *)sender {
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
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) return;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *name = [NSString stringWithFormat:@"ScarletX_DiagnosticLog_%@.json", [formatter stringFromDate:[NSDate date]]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    if (![data writeToURL:url atomically:YES]) return;
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.sourceView = sender;
    share.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:share animated:YES completion:nil];
}

- (void)sx_exportDiagnostics:(UIButton *)sender {
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; } @catch (__unused NSException *e) {}
    if (!webView) { [self sx_shareDiagnostics:sender]; return; }

    NSString *script = @"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var img=p&&p.querySelector('img');var dialogs=document.querySelectorAll('[role=dialog],[role=menu]');var buttons=document.querySelectorAll('button[aria-label$=\\\"に切り替える\\\"]');return {probe:'closed-dom',profileExists:!!p,profileExpanded:p?(p.getAttribute('aria-expanded')||''):'',profileLabel:p?(p.getAttribute('aria-label')||''):'',profileImage:img?(img.currentSrc||img.src||''):'',dialogCount:dialogs.length,switchButtonCount:buttons.length,switchLabels:Array.from(buttons).map(function(b){return b.getAttribute('aria-label')||'';})};})()";
    __weak typeof(self) weakSelf = self;
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        if (error) {
            [[DiagnosticsStore shared] addError:@"Closed DOM snapshot failed" error:error url:webView.URL];
        } else {
            NSData *json = [NSJSONSerialization dataWithJSONObject:[result isKindOfClass:NSDictionary.class] ? result : @{} options:NSJSONWritingPrettyPrinted error:nil];
            NSString *detail = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";
            [[DiagnosticsStore shared] addEvent:@"Closed DOM snapshot" detail:detail url:webView.URL];
        }
        [self sx_shareDiagnostics:sender];
    }];
}

@end
