#import "BrowserViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (AccountSwitchOriginal)
- (void)nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path;
@end

@implementation BrowserViewController (AccountSwitch)
static char SXSwitchingKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method a=class_getInstanceMethod(self,@selector(nativeDrawer:didSelectPath:));
        Method b=class_getInstanceMethod(self,@selector(sx_switch_nativeDrawer:didSelectPath:));
        if(a&&b)method_exchangeImplementations(a,b);
    });
}

- (void)sx_switch_nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    if(![path hasPrefix:@"/__scarletx_account_probe"]){ [self sx_switch_nativeDrawer:drawer didSelectPath:path]; return; }
    if([objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;

    NSURLComponents *c=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *target=@"";
    for(NSURLQueryItem *q in c.queryItems)if([q.name isEqual:@"screen_name"])target=q.value?:@"";
    if(!target.length)return;

    WKWebView *web=nil;
    @try { web=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![web isKindOfClass:WKWebView.class])return;

    objc_setAssociatedObject(self,&SXSwitchingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[DiagnosticsStore shared] addEvent:@"Account switch start" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];

    NSString *open=@"(function(){var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');if(!p)return false;window.__scarletXNativeBypass=true;p.click();return true;})()";
    __weak typeof(self) weakSelf=self;
    [web evaluateJavaScript:open completionHandler:^(id r,NSError *e){
        typeof(self) self=weakSelf;if(!self)return;
        if(e||![r boolValue]){objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}

        for(NSNumber *d in @[@0.2,@0.5,@1.0]){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                typeof(self) self=weakSelf;if(!self||![objc_getAssociatedObject(self,&SXSwitchingKey) boolValue])return;
                NSString *escaped=[target stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                NSString *js=[NSString stringWithFormat:@"(function(){var want='@%@に切り替える';var bs=Array.from(document.querySelectorAll('button'));var hit=bs.find(function(b){return (b.getAttribute('aria-label')||'')===want;});if(!hit)return {found:false};window.__scarletXNativeBypass=false;hit.click();return {found:true,aria:want};})()",escaped];
                [web evaluateJavaScript:js completionHandler:^(id result,NSError *error){
                    if(error)return;
                    NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
                    if([dict[@"found"] boolValue])[[DiagnosticsStore shared] addEvent:@"Account switch button clicked" detail:[NSString stringWithFormat:@"target=@%@ attempt=%@",target,d] url:web.URL];
                }];
            });
        }

        for(NSNumber *d in @[@2,@5,@8]){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                typeof(self) self=weakSelf;if(!self)return;
                NSString *verify=@"(function(){var p=document.querySelector('[data-testid=\"DashButton_ProfileIcon_Link\"]');var h=p?(p.getAttribute('href')||''):'';return {screenName:(h.charAt(0)==='/'&&h.indexOf('/',1)<0)?h.slice(1):'',href:h};})()";
                [web evaluateJavaScript:verify completionHandler:^(id result,NSError *error){
                    if(error)return;
                    NSDictionary *dict=[result isKindOfClass:NSDictionary.class]?result:nil;
                    NSString *screen=[dict[@"screenName"] isKindOfClass:NSString.class]?dict[@"screenName"]:@"";
                    if([screen isEqualToString:target]){
                        [[DiagnosticsStore shared] addEvent:@"Account switch success" detail:[NSString stringWithFormat:@"target=@%@",target] url:web.URL];
                        objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    } else if(d.integerValue==8){
                        [[DiagnosticsStore shared] addEvent:@"Account switch timeout" detail:[NSString stringWithFormat:@"target=@%@ current=@%@",target,screen] url:web.URL];
                        objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        [web evaluateJavaScript:@"window.__scarletXNativeBypass=false" completionHandler:nil];
                    }
                }];
            });
        }
    }];
}
@end
