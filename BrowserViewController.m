#import "BrowserViewController.h"
#import "SettingsViewController.h"
#import "DiagnosticsStore.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) UIToolbar *toolbar;
@property(nonatomic,strong) NSURL *pendingURL;
@end

@implementation BrowserViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [[DiagnosticsStore shared] addEvent:@"App launched" detail:@"Browser view created" url:nil];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;

    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    UIBarButtonItem *forward = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    UIBarButtonItem *home = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"house"] style:UIBarButtonItemStylePlain target:self action:@selector(goHome)];
    UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadPage)];
    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.toolbar = [UIToolbar new];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbar.items = @[back,flex,forward,flex,home,flex,reload,flex,settings];

    [self.view addSubview:self.webView]; [self.view addSubview:self.toolbar];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
      [self.webView.topAnchor constraintEqualToAnchor:safe.topAnchor],
      [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
      [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [self.webView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor],
      [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
      [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [self.toolbar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
    ]];

    if (self.pendingURL) { NSURL *u=self.pendingURL; self.pendingURL=nil; [self loadURL:u reason:@"pending"]; }
    else [self goHome];
}
- (BOOL)isWebURL:(NSURL *)url { NSString *s=url.scheme.lowercaseString; return [s isEqual:@"https"]||[s isEqual:@"http"]; }
- (NSURL *)unwrapScarletURL:(NSURL *)url {
    if (![[url.scheme lowercaseString] isEqual:@"scarletx"]) return url;
    NSURLComponents *c=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *i in c.queryItems) if ([i.name isEqual:@"url"]&&i.value.length) { NSURL *u=[NSURL URLWithString:i.value]; if(u)return u; }
    return [NSURL URLWithString:@"https://x.com/"];
}
- (void)openExternalURL:(NSURL *)url source:(NSString *)source {
    if(!url)return; NSURL *target=[self unwrapScarletURL:url];
    [[DiagnosticsStore shared] addEvent:@"Received external URL" detail:source ?: @"" url:target];
    dispatch_async(dispatch_get_main_queue(), ^{ if(!self.isViewLoaded)self.pendingURL=target; else [self loadURL:target reason:source]; });
}
- (void)loadURL:(NSURL *)url reason:(NSString *)reason {
    if(![self isWebURL:url]) { [[DiagnosticsStore shared] addEvent:@"Unsupported URL" detail:url.scheme ?: @"" url:url]; return; }
    [[DiagnosticsStore shared] addEvent:@"Loading URL" detail:reason ?: @"" url:url];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}
- (void)goHome { [self loadURL:[NSURL URLWithString:@"https://x.com/home"] reason:@"Home"]; }
- (void)goBack { if(self.webView.canGoBack)[self.webView goBack]; }
- (void)goForward { if(self.webView.canGoForward)[self.webView goForward]; }
- (void)reloadPage { [[DiagnosticsStore shared] addEvent:@"Reload" detail:@"" url:self.webView.URL]; [self.webView reload]; }
- (void)openSettings {
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[SettingsViewController new]];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation { [[DiagnosticsStore shared] addEvent:@"Navigation started" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { [[DiagnosticsStore shared] addEvent:@"Navigation finished" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [[DiagnosticsStore shared] addError:@"Provisional navigation failed" error:error url:webView.URL]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { [[DiagnosticsStore shared] addError:@"Navigation failed" error:error url:webView.URL]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { [[DiagnosticsStore shared] addEvent:@"Web content process terminated" detail:@"" url:webView.URL]; }
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)a decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url=a.request.URL; NSString *s=url.scheme.lowercaseString;
    if([self isWebURL:url]||[s isEqual:@"about"]||[s isEqual:@"blob"]||[s isEqual:@"data"]) { decisionHandler(WKNavigationActionPolicyAllow); return; }
    if ([s isEqual:@"x-safari-https"]) {
        [[DiagnosticsStore shared] addEvent:@"Intercepted x-safari-https" detail:@"Keeping X navigation inside ScarletX" url:url];

        NSString *path = url.path.length ? url.path : @"/";
        NSString *query = url.query.length ? [@"?" stringByAppendingString:url.query] : @"";
        NSURL *target = nil;

        if ([url.host.lowercaseString isEqual:@"redirect.x.com"]) {
            target = [NSURL URLWithString:[NSString stringWithFormat:@"https://x.com%@%@", path, query]];
        } else {
            NSString *absolute = url.absoluteString;
            NSString *converted = [absolute stringByReplacingOccurrencesOfString:@"x-safari-https://" withString:@"https://"];
            target = [NSURL URLWithString:converted];
        }

        decisionHandler(WKNavigationActionPolicyCancel);
        if (target) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadURL:target reason:@"x-safari-https intercepted"];
            });
        }
        return;
    }

    [[DiagnosticsStore shared] addEvent:@"Blocked scheme" detail:s ?: @"" url:url];
    decisionHandler(WKNavigationActionPolicyCancel);
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)a windowFeatures:(WKWindowFeatures *)windowFeatures {
    if(a.targetFrame==nil&&a.request.URL)[webView loadRequest:a.request]; return nil;
}
@end
