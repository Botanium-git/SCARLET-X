#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (InternalProfileAPIProfileEntryRecovery240Private)
- (void)sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer;
- (NSString *)sx_internalProfileAPI_fiberRecoveryScript;
@end

@implementation BrowserViewController (InternalProfileAPIProfileEntryRecovery240)

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls=self;
        Method target=class_getInstanceMethod(cls,@selector(sx_internalProfileAPI_nativeDrawerDidSelectNativeProfile:));
        Method replacement=class_getInstanceMethod(cls,@selector(sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:));
        if(target&&replacement){
            method_exchangeImplementations(target,replacement);
        }
    });
}

- (void)sx240_scheduleProfileEntryRecoveryForWebView:(WKWebView *)webView {
    if(![webView isKindOfClass:WKWebView.class])return;
    NSString *probe=[self sx_internalProfileAPI_fiberRecoveryScript];
    if(probe.length==0)return;

    [[DiagnosticsStore shared] addEvent:@"Internal profile API profile-entry recovery scheduled"
                                 detail:@"delays=0,0.75,2.0,4.5"
                                    url:webView.URL];

    __weak WKWebView *weakWebView=webView;
    for(NSNumber *delay in @[@0.0,@0.75,@2.0,@4.5]){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            WKWebView *strongWebView=weakWebView;
            if(!strongWebView)return;
            [strongWebView evaluateJavaScript:probe completionHandler:^(id result,NSError *error){
                if(error){
                    [[DiagnosticsStore shared] addError:@"Internal profile API profile-entry recovery evaluate failed" error:error url:strongWebView.URL];
                }
            }];
        });
    }
}

- (void)sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:(NativeDrawerViewController *)drawer {
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    if([webView isKindOfClass:WKWebView.class]){
        [self sx240_scheduleProfileEntryRecoveryForWebView:webView];
    }

    [self sx240_internalProfileAPI_nativeDrawerDidSelectNativeProfile:drawer];
}

@end
