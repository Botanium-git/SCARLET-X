#import "BrowserViewController.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@implementation BrowserViewController (PortraitMediaFix)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidLoad));
        Method replacement = class_getInstanceMethod(self, @selector(sx_portraitFix_viewDidLoad));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (void)sx_portraitFix_viewDidLoad {
    [self sx_portraitFix_viewDidLoad];

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"webView"]; }
    @catch (__unused NSException *exception) { webView = nil; }
    if (!webView) return;

    NSString *script = @"(function(){"
      "if(window.__scarletXPortraitStableFix171Installed)return;window.__scarletXPortraitStableFix171Installed=true;"
      "var queued=false;"
      "function isPostDetail(){return /^\\/[^\\/]+\\/status\\/\\d+/.test(location.pathname||'');}"
      "var style=document.createElement('style');style.id='scarletx-portrait-stable-171';"
      "style.textContent='.sx-pf171{box-sizing:border-box!important;width:var(--sx-pf-w)!important;height:var(--sx-pf-h)!important;max-width:var(--sx-pf-w)!important;max-height:var(--sx-pf-h)!important;min-width:0!important;min-height:0!important;flex:0 0 auto!important;}';"
      "(document.head||document.documentElement).appendChild(style);"
      "function apply(){queued=false;if(!isPostDetail())return;"
        "var articles=Array.from(document.querySelectorAll('article[data-testid=\\\"tweet\\\"]'));"
        "var main=articles.find(function(a){return !!a.querySelector('[data-testid=\\\"tweetText\\\"]');})||articles[0];if(!main)return;"
        "var photos=Array.from(main.querySelectorAll('[data-testid=\\\"tweetPhoto\\\"]'));if(photos.length!==1)return;"
        "var photo=photos[0],img=photo.querySelector('img');if(!img)return;"
        "var nw=img.naturalWidth||0,nh=img.naturalHeight||0;if(!(nw>0&&nh>0&&nh>nw*1.15))return;"
        "if(photo.dataset.sxPf171==='1')return;"
        "photo.classList.add('sx-portrait-photo');"
        "requestAnimationFrame(function(){if(!photo.isConnected||!img.isConnected||photo.dataset.sxPf171==='1')return;"
          "var ir=img.getBoundingClientRect(),pr=photo.getBoundingClientRect();if(!(ir.width>0&&ir.height>0&&pr.height>0))return;"
          "var shells=[],n=photo;for(var i=0;n&&i<10;i++,n=n.parentElement){var r=n.getBoundingClientRect();if(Math.abs(r.y-pr.y)>3||Math.abs(r.height-pr.height)>4)break;shells.push(n);}"
          "if(!shells.length)return;photo.dataset.sxPf171='1';"
          "shells.forEach(function(el){var cs=getComputedStyle(el),bw=(parseFloat(cs.borderLeftWidth)||0)+(parseFloat(cs.borderRightWidth)||0),bh=(parseFloat(cs.borderTopWidth)||0)+(parseFloat(cs.borderBottomWidth)||0);el.classList.add('sx-pf171');el.style.setProperty('--sx-pf-w',Math.max(1,ir.width+bw)+'px');el.style.setProperty('--sx-pf-h',Math.max(1,ir.height+bh)+'px');});"
        "});"
      "}"
      "function schedule(){if(queued)return;queued=true;requestAnimationFrame(apply);}"
      "schedule();new MutationObserver(schedule).observe(document.documentElement,{childList:true,subtree:true});window.addEventListener('popstate',schedule,true);"
    "})();";

    [webView.configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
    [webView evaluateJavaScript:script completionHandler:nil];
}

@end
