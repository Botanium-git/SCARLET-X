#import "BrowserViewController.h"
#import <WebKit/WebKit.h>

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSURL *pendingURL;
@end

@implementation BrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;

    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    UIBarButtonItem *forward = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadPage)];
    UIBarButtonItem *home = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"house"] style:UIBarButtonItemStylePlain target:self action:@selector(goHome)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0,170,30)];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"ScarletX v0.1.0";
    UIBarButtonItem *status = [[UIBarButtonItem alloc] initWithCustomView:self.statusLabel];

    self.toolbar = [UIToolbar new];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbar.items = @[back, flex, forward, flex, home, flex, reload, flex, status];

    [self.view addSubview:self.webView];
    [self.view addSubview:self.toolbar];
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

    if (self.pendingURL) {
        NSURL *u = self.pendingURL; self.pendingURL = nil;
        [self loadURL:u reason:@"pending"];
    } else {
        [self goHome];
    }
}

- (BOOL)isWebURL:(NSURL *)url {
    NSString *scheme = url.scheme.lowercaseString;
    return [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"];
}

- (NSURL *)unwrapScarletURL:(NSURL *)url {
    if (![[url.scheme lowercaseString] isEqualToString:@"scarletx"]) return url;
    NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in c.queryItems) {
        if ([item.name isEqualToString:@"url"] && item.value.length) {
            NSURL *nested = [NSURL URLWithString:item.value];
            if (nested) return nested;
        }
    }
    return [NSURL URLWithString:@"https://x.com/"];
}

- (void)openExternalURL:(NSURL *)url source:(NSString *)source {
    if (!url) return;
    NSURL *target = [self unwrapScarletURL:url];
    NSLog(@"[ScarletX] incoming via %@: %@", source, target.absoluteString);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isViewLoaded) self.pendingURL = target;
        else [self loadURL:target reason:[NSString stringWithFormat:@"IN: %@", source]];
    });
}

- (void)loadURL:(NSURL *)url reason:(NSString *)reason {
    if (![self isWebURL:url]) {
        self.statusLabel.text = [NSString stringWithFormat:@"Unsupported\n%@", url.scheme ?: @"(none)"];
        return;
    }
    self.statusLabel.text = reason;
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}

- (void)goHome { [self loadURL:[NSURL URLWithString:@"https://x.com/home"] reason:@"HOME"]; }
- (void)goBack { if (self.webView.canGoBack) [self.webView goBack]; }
- (void)goForward { if (self.webView.canGoForward) [self.webView goForward]; }
- (void)reloadPage { [self.webView reload]; }

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.statusLabel.text = webView.URL.host ?: @"Loaded";
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.statusLabel.text = [NSString stringWithFormat:@"ERR %ld\n%@", (long)error.code, error.localizedDescription];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if ([self isWebURL:url] || [url.scheme.lowercaseString isEqualToString:@"about"] || [url.scheme.lowercaseString isEqualToString:@"blob"] || [url.scheme.lowercaseString isEqualToString:@"data"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    NSLog(@"[ScarletX] blocked non-web navigation: %@", url.absoluteString);
    self.statusLabel.text = [NSString stringWithFormat:@"Blocked\n%@", url.scheme ?: @"scheme"];
    decisionHandler(WKNavigationActionPolicyCancel);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (navigationAction.targetFrame == nil && navigationAction.request.URL) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

@end
