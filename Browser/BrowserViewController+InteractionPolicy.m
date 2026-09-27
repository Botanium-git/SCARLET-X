#import "BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static const void *SXTextInteractionBridgeKey = &SXTextInteractionBridgeKey;

@interface SXTextInteractionBridge : NSObject <WKScriptMessageHandler>
@property(nonatomic,weak) WKWebView *webView;
@end

@implementation SXTextInteractionBridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    BOOL enabled = NO;
    if ([message.body respondsToSelector:@selector(boolValue)]) enabled = [message.body boolValue];
    WKPreferences *preferences = self.webView.configuration.preferences;
    if (@available(iOS 15.0, *)) preferences.textInteractionEnabled = enabled;
}
@end

@implementation BrowserViewController (InteractionPolicy)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_interactionPolicy_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)sx_interactionPolicy_viewDidLoad {
    [self sx_interactionPolicy_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; }
    @catch (__unused NSException *exception) { webView = nil; }
    if (!webView) return;

    webView.allowsLinkPreview = NO;
    if (@available(iOS 15.0, *)) webView.configuration.preferences.textInteractionEnabled = NO;

    SXTextInteractionBridge *bridge = [SXTextInteractionBridge new];
    bridge.webView = webView;
    objc_setAssociatedObject(webView, SXTextInteractionBridgeKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    WKUserContentController *controller = webView.configuration.userContentController;
    [controller removeScriptMessageHandlerForName:@"scarletxTextInteraction"];
    [controller addScriptMessageHandler:bridge name:@"scarletxTextInteraction"];

    NSString *script = @"(function(){"
      "if(window.__scarletXTextInteractionPolicyInstalled)return;window.__scarletXTextInteractionPolicyInstalled=true;"
      "function allowed(t){return !!(t&&t.closest&&t.closest('[data-testid=\\\"tweetText\\\"],input,textarea,[contenteditable=true]'));}"
      "function send(v){try{window.webkit.messageHandlers.scarletxTextInteraction.postMessage(v?1:0);}catch(_){}}"
      "document.addEventListener('touchstart',function(e){send(allowed(e.target));},true);"
      "document.addEventListener('pointerdown',function(e){send(allowed(e.target));},true);"
    "})();";
    [controller addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
    [webView evaluateJavaScript:script completionHandler:nil];
}

- (void)webView:(WKWebView *)webView
contextMenuConfigurationForElement:(WKContextMenuElementInfo *)elementInfo
completionHandler:(void (^)(UIContextMenuConfiguration * _Nullable configuration))completionHandler {
    completionHandler(nil);
}

@end
