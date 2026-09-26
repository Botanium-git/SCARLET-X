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
        Method original=class_getInstanceMethod(self,@selector(nativeDrawer:didSelectPath:));
        Method replacement=class_getInstanceMethod(self,@selector(sx_accountSwitch_nativeDrawer:didSelectPath:));
        if(original&&replacement)method_exchangeImplementations(original,replacement);
    });
}

- (void)sx_accountSwitch_nativeDrawer:(NativeDrawerViewController *)drawer didSelectPath:(NSString *)path {
    if(![path hasPrefix:@"/__scarletx_account_probe"]){
        [self sx_accountSwitch_nativeDrawer:drawer didSelectPath:path];
        return;
    }

    if([objc_getAssociatedObject(self,&SXSwitchingKey) boolValue]){
        [[DiagnosticsStore shared] addEvent:@"Account switch blocked" detail:@"switch already in progress" url:nil];
        return;
    }

    NSURLComponents *components=[NSURLComponents componentsWithString:[@"https://x.com" stringByAppendingString:path ?: @""]];
    NSString *targetScreen=@"";
    for(NSURLQueryItem *item in components.queryItems){
        if([item.name isEqual:@"screen_name"]&&item.value.length)targetScreen=item.value;
    }
    if(targetScreen.length==0){
        [[DiagnosticsStore shared] addEvent:@"Account switch failed" detail:@"missing target screen_name" url:nil];
        return;
    }

    WKWebView *webView=nil;
    @try { webView=[self valueForKey:@"webView"]; } @catch(__unused NSException *e) {}
    if(![webView isKindOfClass:WKWebView.class]){
        [[DiagnosticsStore shared] addEvent:@"Account switch failed" detail:@"webView unavailable" url:nil];
        return;
    }

    objc_setAssociatedObject(self,&SXSwitchingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[DiagnosticsStore shared] addEvent:@"Account switch start" detail:[NSString stringWithFormat:@"target=@%@",targetScreen] url:webView.URL];

    NSDictionary *input=@{@"screenName":targetScreen};
    NSData *inputData=[NSJSONSerialization dataWithJSONObject:input options:0 error:nil];
    NSString *inputJSON=inputData?[[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding]:@"{}";

    NSString *script=[NSString stringWithFormat:@"(function(){var input=%@,target=input.screenName||'';function send(stage,payload){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'account-switch '+stage+' '+JSON.stringify(payload||{})});}catch(_){}}function profileScreen(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var h=p?(p.getAttribute('href')||''):'';return (h.charAt(0)==='/'&&h.indexOf('/',1)<0)?h.slice(1):'';}function candidates(){return Array.from(document.querySelectorAll('button')).map(function(b){return {el:b,aria:b.getAttribute('aria-label')||'',text:((b.innerText||b.textContent)||'').trim(),testid:b.getAttribute('data-testid')||''};}).filter(function(x){return x.aria.slice(-6)==='に切り替える';});}var profile=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');if(!profile){send('profile-not-found',{target:target,url:location.href});window.__scarletXNativeBypass=false;return null;}var before=profileScreen();send('begin',{target:target,before:before,url:location.href});window.__scarletXNativeBypass=true;try{profile.click();}catch(e){window.__scarletXNativeBypass=false;send('profile-click-failed',{target:target,error:String(e)});return null;}var done=false,observer=null,timer=null;function finish(stage,payload){if(done)return;done=true;if(observer)observer.disconnect();if(timer)clearTimeout(timer);window.__scarletXNativeBypass=false;send(stage,payload);}function inspect(){if(done)return;var cs=candidates();var exact=cs.filter(function(x){return x.aria==='@'+target+'に切り替える'||x.aria===target+'に切り替える';});if(exact.length===1){var hit=exact[0];finish('button-found',{target:target,before:before,aria:hit.aria,text:hit.text,testid:hit.testid,candidateCount:cs.length});try{hit.el.click();send('button-clicked',{target:target,aria:hit.aria});}catch(e){send('button-click-failed',{target:target,error:String(e)});}return;}if(exact.length>1){finish('ambiguous',{target:target,count:exact.length,candidates:exact.map(function(x){return {aria:x.aria,text:x.text,testid:x.testid};})});}}
observer=new MutationObserver(inspect);observer.observe(document.documentElement||document.body,{childList:true,subtree:true,attributes:true});setTimeout(inspect,120);setTimeout(inspect,350);setTimeout(inspect,700);setTimeout(inspect,1400);timer=setTimeout(function(){var cs=candidates();finish('target-not-found',{target:target,candidates:cs.map(function(x){return {aria:x.aria,text:x.text,testid:x.testid};})});},3000);return null;})()",inputJSON];

    __weak typeof(self) weakSelf=self;
    [webView evaluateJavaScript:script completionHandler:^(__unused id result,NSError *error){
        typeof(self) self=weakSelf; if(!self)return;
        if(error){
            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [[DiagnosticsStore shared] addError:@"Account switch injection failed" error:error url:webView.URL];
            return;
        }

        NSArray<NSNumber *> *delays=@[@2,@5,@8];
        for(NSNumber *delay in delays){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                typeof(self) self=weakSelf; if(!self)return;
                NSString *verify=@"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var h=p?(p.getAttribute('href')||''):'';var s=(h.charAt(0)==='/'&&h.indexOf('/',1)<0)?h.slice(1):'';return {screenName:s,href:h,url:location.href};})()";
                [webView evaluateJavaScript:verify completionHandler:^(id verifyResult,NSError *verifyError){
                    if(verifyError){
                        [[DiagnosticsStore shared] addError:@"Account switch verification failed" error:verifyError url:webView.URL];
                    } else {
                        NSDictionary *dict=[verifyResult isKindOfClass:NSDictionary.class]?verifyResult:@{};
                        NSString *screen=[dict[@"screenName"] isKindOfClass:NSString.class]?dict[@"screenName"]:@"";
                        NSData *data=[NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
                        NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[dict description];
                        if([screen isEqualToString:targetScreen]){
                            [[DiagnosticsStore shared] addEvent:@"Account switch success" detail:[NSString stringWithFormat:@"target=@%@ %@",targetScreen,detail?:@""] url:webView.URL];
                            objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                            return;
                        }
                        [[DiagnosticsStore shared] addEvent:@"Account switch verify" detail:[NSString stringWithFormat:@"target=@%@ attempt=%@ %@",targetScreen,delay,detail?:@""] url:webView.URL];
                    }
                    if(delay.integerValue==8){
                        objc_setAssociatedObject(self,&SXSwitchingKey,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        [[DiagnosticsStore shared] addEvent:@"Account switch timeout" detail:[NSString stringWithFormat:@"target=@%@",targetScreen] url:webView.URL];
                    }
                }];
            });
        }
    }];
}

@end
