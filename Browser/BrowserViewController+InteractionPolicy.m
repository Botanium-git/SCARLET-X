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
      "var activeTweet=null,clamping=false,suppressProfileClickUntil=0,profilePress=null;"
      "function tweet(t){return t&&t.closest?t.closest('[data-testid=\\\"tweetText\\\"]'):null;}"
      "function editable(t){return !!(t&&t.closest&&t.closest('input,textarea,[contenteditable=true]'));}"
      "function send(v){try{window.webkit.messageHandlers.scarletxTextInteraction.postMessage(v?1:0);}catch(_){}}"
      "function setInteractionForTarget(t){activeTweet=tweet(t);send(!!activeTweet||editable(t));}"
      "document.addEventListener('touchstart',function(e){setInteractionForTarget(e.target);var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(p&&e.touches&&e.touches.length){var q=e.touches[0];profilePress={x:q.clientX,y:q.clientY,t:Date.now(),cancelled:false};}},true);"
      "document.addEventListener('pointerdown',function(e){setInteractionForTarget(e.target);},true);"
      "document.addEventListener('touchmove',function(e){if(!profilePress||!e.touches||!e.touches.length)return;var q=e.touches[0],dx=q.clientX-profilePress.x,dy=q.clientY-profilePress.y;if((dx*dx+dy*dy)>144)profilePress.cancelled=true;},true);"
      "document.addEventListener('touchcancel',function(){profilePress=null;},true);"
      "document.addEventListener('touchend',function(){if(profilePress&&!profilePress.cancelled&&(Date.now()-profilePress.t)>=500)suppressProfileClickUntil=Date.now()+1200;profilePress=null;},true);"
      "document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p||Date.now()>=suppressProfileClickUntil)return;suppressProfileClickUntil=0;e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();},true);"
      "document.addEventListener('selectionchange',function(){if(clamping||!activeTweet)return;var s=window.getSelection&&window.getSelection();if(!s||!s.rangeCount)return;var r=s.getRangeAt(0).cloneRange();var limit=document.createRange();limit.selectNodeContents(activeTweet);var changed=false;function inside(n){if(!n)return false;var el=n.nodeType===3?n.parentNode:n;return el===activeTweet||activeTweet.contains(el);}try{if(!inside(r.startContainer)){r.setStart(limit.startContainer,limit.startOffset);changed=true;}if(!inside(r.endContainer)){r.setEnd(limit.endContainer,limit.endOffset);changed=true;}if(changed){clamping=true;s.removeAllRanges();s.addRange(r);setTimeout(function(){clamping=false;},0);}}catch(_){clamping=false;}},true);"
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
