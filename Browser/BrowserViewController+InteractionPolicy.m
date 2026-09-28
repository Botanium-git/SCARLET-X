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
      "var activeTweet=null,clamping=false,suppressProfileClickUntil=0,profilePress=null,layoutQueued=false;"
      "function isPostDetail(){return /^\\/[^\\/]+\\/status\\/\\d+/.test(location.pathname||'');}"
      "function tweet(t){if(!isPostDetail())return null;return t&&t.closest?t.closest('[data-testid=\\\"tweetText\\\"]'):null;}"
      "function editable(t){return !!(t&&t.closest&&t.closest('input,textarea,[contenteditable=true]'));}"
      "function send(v){try{window.webkit.messageHandlers.scarletxTextInteraction.postMessage(v?1:0);}catch(_){}}"
      "function setInteractionForTarget(t){activeTweet=tweet(t);send(!!activeTweet||editable(t));}"
      "var style=document.createElement('style');style.id='scarletx-app-density';"
      "style.textContent='@font-face{font-family:\"SXChirp\";src:url(https://abs.twimg.com/fonts/subset/Chirp-Regular.c88864db.latin.woff2) format(\"woff2\");font-style:normal;font-weight:400;font-display:swap;}@font-face{font-family:\"SXChirp\";src:url(https://abs.twimg.com/fonts/subset/Chirp-Medium.ca6d679a.latin.woff2) format(\"woff2\");font-style:normal;font-weight:500;font-display:swap;}@font-face{font-family:\"SXChirp\";src:url(https://abs.twimg.com/fonts/subset/Chirp-Bold.d8ac01b2.latin.woff2) format(\"woff2\");font-style:normal;font-weight:700;font-display:swap;}article[data-testid=\\\"tweet\\\"] [data-testid=\\\"tweetText\\\"],article[data-testid=\\\"tweet\\\"] [data-testid=\\\"tweetText\\\"] *{font-family:\"SXChirp\",-apple-system,BlinkMacSystemFont,sans-serif!important;font-size:14px!important;line-height:18px!important;}article[data-testid=\\\"tweet\\\"] [data-testid=\\\"User-Name\\\"],article[data-testid=\\\"tweet\\\"] [data-testid=\\\"User-Name\\\"] *{font-family:\"SXChirp\",-apple-system,BlinkMacSystemFont,sans-serif!important;font-size:13px!important;line-height:16px!important;}article[data-testid=\\\"tweet\\\"] [data-testid=\\\"User-Name\\\"] time,article[data-testid=\\\"tweet\\\"] [data-testid=\\\"User-Name\\\"] time *{font-size:13px!important;line-height:16px!important;}article[data-testid=\\\"tweet\\\"] [role=\\\"group\\\"] svg{width:18px!important;height:18px!important;}article[data-testid=\\\"tweet\\\"] [role=\\\"group\\\"] [data-testid=\\\"app-text-transition-container\\\"],article[data-testid=\\\"tweet\\\"] [role=\\\"group\\\"] [data-testid=\\\"app-text-transition-container\\\"] *{font-family:\"SXChirp\",-apple-system,BlinkMacSystemFont,sans-serif!important;font-size:12px!important;line-height:15px!important;}article.sx-main-post [data-testid=\\\"tweetText\\\"],article.sx-main-post [data-testid=\\\"tweetText\\\"] *{font-size:14px!important;line-height:18px!important;}article.sx-main-post [data-testid=\\\"tweetText\\\"]{margin-top:4px!important;margin-bottom:10px!important;}article.sx-main-post [role=\\\"group\\\"] svg{width:17px!important;height:17px!important;}article.sx-main-post [data-testid=\\\"User-Name\\\"] .sx-display-name{font-size:14px!important;line-height:18px!important;}article.sx-main-post .sx-portrait-photo img{width:auto!important;height:auto!important;max-height:44vh!important;max-width:calc(100vw - 32px)!important;object-fit:contain!important;object-position:left top!important;}article.sx-main-post .sx-portrait-photo{max-width:calc(100vw - 32px)!important;overflow:hidden!important;border-radius:16px!important;}';"
      "(document.head||document.documentElement).appendChild(style);"
      "function clearPostLayout(){Array.from(document.querySelectorAll('article.sx-main-post')).forEach(function(a){a.classList.remove('sx-main-post');});Array.from(document.querySelectorAll('.sx-portrait-photo')).forEach(function(p){p.classList.remove('sx-portrait-photo');});}"
      "function applyPostLayout(){layoutQueued=false;if(!isPostDetail()){clearPostLayout();return;}var articles=Array.from(document.querySelectorAll('article[data-testid=\\\"tweet\\\"]'));if(!articles.length)return;var main=articles.find(function(a){return !!a.querySelector('[data-testid=\\\"tweetText\\\"]');})||articles[0];Array.from(document.querySelectorAll('article.sx-main-post')).forEach(function(a){if(a!==main)a.classList.remove('sx-main-post');});main.classList.add('sx-main-post');var un=main.querySelector('[data-testid=\\\"User-Name\\\"]');if(un){Array.from(un.querySelectorAll('*')).forEach(function(n){n.classList.remove('sx-display-name');var fw=parseInt(getComputedStyle(n).fontWeight,10)||0;if(fw>=600&&(n.textContent||'').trim())n.classList.add('sx-display-name');});}var photos=Array.from(main.querySelectorAll('[data-testid=\\\"tweetPhoto\\\"]'));photos.forEach(function(p){p.classList.remove('sx-portrait-photo');});if(photos.length!==1)return;var photo=photos[0],img=photo.querySelector('img');if(!img)return;function classify(){var w=img.naturalWidth||0,h=img.naturalHeight||0;if(w>0&&h>0&&h>w*1.15)photo.classList.add('sx-portrait-photo');else photo.classList.remove('sx-portrait-photo');}classify();if(!img.complete)img.addEventListener('load',classify,{once:true});}"
      "function schedulePostLayout(){if(layoutQueued)return;layoutQueued=true;requestAnimationFrame(applyPostLayout);}"
      "schedulePostLayout();new MutationObserver(schedulePostLayout).observe(document.documentElement,{childList:true,subtree:true});window.addEventListener('popstate',schedulePostLayout,true);"
      "document.addEventListener('touchstart',function(e){setInteractionForTarget(e.target);var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(p&&e.touches&&e.touches.length){var q=e.touches[0];profilePress={x:q.clientX,y:q.clientY,t:Date.now(),cancelled:false};}},true);"
      "document.addEventListener('pointerdown',function(e){setInteractionForTarget(e.target);},true);"
      "document.addEventListener('touchmove',function(e){if(!profilePress||!e.touches||!e.touches.length)return;var q=e.touches[0],dx=q.clientX-profilePress.x,dy=q.clientY-profilePress.y;if((dx*dx+dy*dy)>144)profilePress.cancelled=true;},true);"
      "document.addEventListener('touchcancel',function(){profilePress=null;},true);"
      "document.addEventListener('touchend',function(){if(profilePress&&!profilePress.cancelled&&(Date.now()-profilePress.t)>=500)suppressProfileClickUntil=Date.now()+1200;profilePress=null;},true);"
      "document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p||Date.now()>=suppressProfileClickUntil)return;suppressProfileClickUntil=0;e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();},true);"
      "document.addEventListener('selectionchange',function(){if(clamping||!activeTweet||!isPostDetail())return;var s=window.getSelection&&window.getSelection();if(!s||!s.rangeCount)return;var r=s.getRangeAt(0).cloneRange();var limit=document.createRange();limit.selectNodeContents(activeTweet);var changed=false;function inside(n){if(!n)return false;var el=n.nodeType===3?n.parentNode:n;return el===activeTweet||activeTweet.contains(el);}try{if(!inside(r.startContainer)){r.setStart(limit.startContainer,limit.startOffset);changed=true;}if(!inside(r.endContainer)){r.setEnd(limit.endContainer,limit.endOffset);changed=true;}if(changed){clamping=true;s.removeAllRanges();s.addRange(r);setTimeout(function(){clamping=false;},0);}}catch(_){clamping=false;}},true);"
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
