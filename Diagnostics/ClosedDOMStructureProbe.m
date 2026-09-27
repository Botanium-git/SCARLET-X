#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "../Diagnostics/DiagnosticsStore.h"
#import "../Browser/BrowserViewController.h"

@implementation BrowserViewController (ClosedDOMStructureProbe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(webView:didFinishNavigation:));
        Method probe = class_getInstanceMethod(self, @selector(sx_probe_webView:didFinishNavigation:));
        if (original && probe) method_exchangeImplementations(original, probe);
    });
}

- (void)sx_probe_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self sx_probe_webView:webView didFinishNavigation:navigation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *script = @"(function(){function c(s){try{return document.querySelectorAll(s).length}catch(e){return -1}}function pathKind(h){if(!h)return 'empty';try{var u=new URL(h,location.href);if(u.origin!==location.origin)return 'external';var p=u.pathname||'/';if(p==='/'||p==='/home')return 'home';if(/^\\/[A-Za-z0-9_]{1,15}\\/?$/.test(p))return 'single-segment';if(p.indexOf('/i/')===0)return 'internal-i';if(p.indexOf('/settings')===0)return 'settings';if(p.indexOf('/messages')===0)return 'messages';if(p.indexOf('/notifications')===0)return 'notifications';if(p.indexOf('/search')===0||p==='/explore')return 'discovery';return 'other';}catch(e){return 'invalid'}}function srcOf(img){return img?(img.currentSrc||img.getAttribute('src')||''):''}function visible(el){if(!el)return false;var r=el.getBoundingClientRect(),s=getComputedStyle(el);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'}var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var profileImg=p&&p.querySelector('img');var profileSrc=srcOf(profileImg);var links=Array.from(document.querySelectorAll('a[href]'));var kinds={};links.forEach(function(a){var k=pathKind(a.getAttribute('href')||'');kinds[k]=(kinds[k]||0)+1;});var near=[];if(p){var root=p.parentElement&&p.parentElement.parentElement?p.parentElement.parentElement:p.parentElement;Array.from((root||document).querySelectorAll('a[href]')).slice(0,20).forEach(function(a){near.push(pathKind(a.getAttribute('href')||''));});}var singles=[];links.forEach(function(a,i){if(pathKind(a.getAttribute('href')||'')!=='single-segment')return;var img=a.querySelector('img'),r=a.getBoundingClientRect();singles.push({index:i,visible:visible(a),inNav:!!a.closest('nav'),hasImage:!!img,sameProfileImage:!!(profileSrc&&srcOf(img)===profileSrc),textLength:(a.innerText||a.textContent||'').trim().length,hasAriaLabel:!!a.getAttribute('aria-label'),hasTestId:!!a.getAttribute('data-testid'),xBucket:Math.round(r.left/50),yBucket:Math.round(r.top/50)});});return {profileButton:!!p,profileImage:!!profileImg,profileAriaLabel:!!(p&&p.hasAttribute('aria-label')),profileHref:!!(p&&p.hasAttribute('href')),profileExpanded:p?(p.getAttribute('aria-expanded')||''):null,dialogs:c('[role=\\\"dialog\\\"]'),menus:c('[role=\\\"menu\\\"]'),accountSwitcher:c('[data-testid=\\\"SideNav_AccountSwitcher_Button\\\"]'),accountSwitchButtons:c('button[aria-label$=\\\"に切り替える\\\"]'),navLinks:c('nav a[href]'),allLinks:links.length,linkKinds:kinds,nearProfileLinkKinds:near,singleSegmentCandidates:singles,images:c('img')};})()";
        [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if (error) {
                [[DiagnosticsStore shared] addEvent:@"Closed DOM structure" detail:[NSString stringWithFormat:@"probe failed: %@", error.localizedDescription ?: @"unknown"] url:webView.URL];
                return;
            }
            NSData *data = [NSJSONSerialization dataWithJSONObject:[result isKindOfClass:NSDictionary.class] ? result : @{} options:0 error:nil];
            NSString *detail = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"{}";
            [[DiagnosticsStore shared] addEvent:@"Closed DOM structure" detail:detail url:webView.URL];
        }];
    });
}

@end
