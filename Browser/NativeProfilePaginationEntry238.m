#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController (NativeProfilePagination238PrivateEntry)
- (void)sx238_loadMoreTab:(NSInteger)tab profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView;
@end

@implementation BrowserViewController (NativeProfilePaginationEntry238)

- (void)sx238_loadMoreProfile:(NativeProfileViewController *)profile {
    if(!profile)return;
    NSInteger tab=0;
    @try { tab=[[profile valueForKey:@"selectedProfileTab"] integerValue]; } @catch(__unused NSException *exception) {}
    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *exception) {}
    if(![webView isKindOfClass:WKWebView.class])return;
    [self sx238_loadMoreTab:tab profile:profile sourceWebView:webView];
}

@end
