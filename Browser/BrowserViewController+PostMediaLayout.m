#import "BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@implementation BrowserViewController (PostMediaLayout)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_postMediaLayout_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)sx_postMediaLayout_viewDidLoad {
    [self sx_postMediaLayout_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; }
    @catch (__unused NSException *exception) { webView = nil; }
    if (!webView) return;

    NSString *script = @"(function(){"
      "if(window.__scarletXPortraitMediaSizingV2)return;window.__scarletXPortraitMediaSizingV2=true;"
      "var queued=false;"
      "function viewportHeight(){return (window.visualViewport&&window.visualViewport.height)||window.innerHeight||0;}"
      "function clear(photo){['width','max-width','min-width','flex','align-self','margin-right'].forEach(function(k){photo.style.removeProperty(k);});photo.removeAttribute('data-sx-portrait-sized');}"
      "function sizePhoto(photo){var img=photo&&photo.querySelector?photo.querySelector('img'):null;if(!img)return;"
        "function apply(){var w=img.naturalWidth||0,h=img.naturalHeight||0;if(!(w>0&&h>0&&h>w*1.15)){clear(photo);return;}"
          "var vh=viewportHeight(),maxH=vh>0?vh*0.44:0,maxW=Math.max(0,(window.innerWidth||0)-32);if(!(maxH>0&&maxW>0))return;"
          "var target=Math.round(Math.min(maxW,maxH*(w/h)));if(!(target>0))return;"
          "photo.style.setProperty('width',target+'px','important');photo.style.setProperty('max-width',target+'px','important');photo.style.setProperty('min-width','0px','important');photo.style.setProperty('flex','0 0 auto','important');photo.style.setProperty('align-self','flex-start','important');photo.style.setProperty('margin-right','auto','important');photo.setAttribute('data-sx-portrait-sized','1');}"
        "apply();if(!img.complete)img.addEventListener('load',apply,{once:true});}"
      "function run(){queued=false;Array.from(document.querySelectorAll('[data-sx-portrait-sized]')).forEach(function(p){if(!p.matches('article.sx-main-post [data-testid=\\\"tweetPhoto\\\"]'))clear(p);});Array.from(document.querySelectorAll('article.sx-main-post [data-testid=\\\"tweetPhoto\\\"]')).forEach(sizePhoto);}"
      "function schedule(){if(queued)return;queued=true;requestAnimationFrame(run);}"
      "schedule();new MutationObserver(schedule).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class']});window.addEventListener('popstate',schedule,true);window.addEventListener('resize',schedule,true);if(window.visualViewport)window.visualViewport.addEventListener('resize',schedule,true);"
    "})();";

    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [webView.configuration.userContentController addUserScript:userScript];
    [webView evaluateJavaScript:script completionHandler:nil];
}

@end
