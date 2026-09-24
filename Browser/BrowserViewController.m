#import "BrowserViewController.h"
#import "../UI/SettingsViewController.h"
#import "../UI/NativeDrawerViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import "../Scripts/DisplayScripts.h"
#import "../Scripts/DiagnosticsScripts.h"
#import "../Scripts/RuntimeScripts.h"
#import "BrowserViewController+Navigation.h"
#import <WebKit/WebKit.h>

static NSString * const SXNativeUIKey = @"ScarletXNativeUI";

@interface BrowserViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NativeDrawerViewControllerDelegate>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSURL *pendingURL;
@property(nonatomic,assign) CFTimeInterval navigationStartTime;
@property(nonatomic,assign) CFTimeInterval requestStartTime;
@property(nonatomic,assign) NSInteger navigationSession;
@property(nonatomic,assign) BOOL requestPending;
@property(nonatomic,copy) NSString *navigationReason;
@property(nonatomic,strong) NativeDrawerViewController *nativeDrawer;
@end

@interface BrowserViewController (QuickLogExportInternal)
- (void)sx_installQuickLogButton;
@end

@implementation BrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    [[DiagnosticsStore shared] addEvent:@"App launched" detail:@"Browser view created" url:nil];
    WKWebViewConfiguration *config=[WKWebViewConfiguration new];
    WKUserContentController *cc=[WKUserContentController new];
    [cc addScriptMessageHandler:self name:@"scarletx"];
    [DisplayScripts installSettingsScriptInto:cc];
    [DisplayScripts installDisplayCustomizationInto:cc];
    [DiagnosticsScripts installFlagsInto:cc];
    [RuntimeScripts installInto:cc];
    BOOL nativeUI=[[NSUserDefaults standardUserDefaults] boolForKey:SXNativeUIKey];
    [[DiagnosticsStore shared] addEvent:@"Native drawer bridge trace" detail:[NSString stringWithFormat:@"viewDidLoad nativeUI=%@",nativeUI?@"ON":@"OFF"] url:nil];
    if(nativeUI){
        NSString *bridge=@"(function(){if(window.__scarletXNativeDrawerInstalled)return;window.__scarletXNativeDrawerInstalled=true;window.__scarletXNativeBypass=false;try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'bridge-installed'});}catch(_){}document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p||window.__scarletXNativeBypass)return;try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'profile-click-captured'});}catch(_){}e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer'});}catch(err){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'native-drawer-post-failed',error:String(err)});}catch(_){} }},true);})();";
        [cc addUserScript:[[WKUserScript alloc] initWithSource:bridge injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    } else {
        NSString *webProbe=@"(function(){if(window.__scarletXWebMenuProbeInstalled)return;window.__scarletXWebMenuProbeInstalled=true;function desc(el){if(!el)return null;var attrs={};Array.from(el.attributes||[]).forEach(function(a){if(a.name==='class'||a.name==='style')return;attrs[a.name]=a.value;});return {tag:el.tagName||'',attrs:attrs,text:(el.innerText||'').trim().slice(0,2000),html:(el.outerHTML||'').slice(0,10000),images:Array.from(el.querySelectorAll?el.querySelectorAll('img'):[]).slice(0,12).map(function(i){return {src:i.currentSrc||i.src||'',alt:i.alt||''};})};}function switchRows(){return Array.from(document.querySelectorAll('button[aria-label$=\\\"に切り替える\\\"]')).slice(0,8).map(function(b){var chain=[],n=b;for(var depth=0;n&&depth<6;depth++,n=n.parentElement){chain.push({depth:depth,tag:n.tagName||'',role:n.getAttribute?n.getAttribute('role'):null,testid:n.getAttribute?n.getAttribute('data-testid'):null,ariaLabel:n.getAttribute?n.getAttribute('aria-label'):null,text:(n.innerText||n.textContent||'').trim().slice(0,1200),html:(n.outerHTML||'').slice(0,8000),links:Array.from(n.querySelectorAll?n.querySelectorAll('a[href]'):[]).slice(0,8).map(function(a){return {href:a.getAttribute('href')||'',text:(a.innerText||a.textContent||'').trim().slice(0,300),ariaLabel:a.getAttribute('aria-label')||'',testid:a.getAttribute('data-testid')||''};}),images:Array.from(n.querySelectorAll?n.querySelectorAll('img'):[]).slice(0,8).map(function(i){return {src:i.currentSrc||i.src||'',alt:i.alt||'',testid:i.getAttribute('data-testid')||''};})});}return {buttonLabel:b.getAttribute('aria-label')||'',chain:chain};});}function snap(){var selectors=['[data-testid=DashButton_ProfileIcon_Link]','[data-testid=SideNav_AccountSwitcher_Button]','[data-testid=AccountSwitcher_AddAccount_Button]','[data-testid=AccountSwitcher_Logout_Button]'];var found={};selectors.forEach(function(s){found[s]=desc(document.querySelector(s));});var dialogs=Array.from(document.querySelectorAll('[role=dialog],[role=menu]')).slice(-6).map(desc);try{window.webkit.messageHandlers.scarletx.postMessage({type:'web-menu-dom',payload:{url:location.href,found:found,dialogs:dialogs,switchRows:switchRows()}});}catch(_){}}document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p)return;setTimeout(snap,100);setTimeout(snap,400);},true);})();";
        [cc addUserScript:[[WKUserScript alloc] initWithSource:webProbe injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    }
    config.userContentController=cc;
    config.websiteDataStore=WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback=YES;
    config.mediaTypesRequiringUserActionForPlayback=WKAudiovisualMediaTypeNone;
    self.webView=[[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.customUserAgent=@"Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1";
    self.webView.navigationDelegate=self;
    self.webView.UIDelegate=self;
    self.webView.allowsBackForwardNavigationGestures=YES;
    self.webView.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:self.webView];
    [NSLayoutConstraint activateConstraints:@[[self.webView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
    [self sx_installQuickLogButton];
    if(self.pendingURL){NSURL*u=self.pendingURL;self.pendingURL=nil;[self loadURL:u reason:@"pending"];}else[self goHome];
}

- (void)openExternalURL:(NSURL*)url source:(NSString*)source { if(!url)return; NSURL*target=[self unwrapScarletURL:url]; dispatch_async(dispatch_get_main_queue(),^{if(!self.isViewLoaded)self.pendingURL=target;else[self loadURL:target reason:source];}); }

- (void)userContentController:(WKUserContentController*)u didReceiveScriptMessage:(WKScriptMessage*)m {
    if(![m.name isEqual:@"scarletx"])return;
    if([m.body isEqual:@"settings"]){[self openSettings];return;}
    if([m.body isKindOfClass:NSDictionary.class]){
        NSString *type=m.body[@"type"];
        if([type isEqual:@"web-menu-dom"]){ id payload=m.body[@"payload"]?:@{}; NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil]; NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[payload description]; [[DiagnosticsStore shared] addEvent:@"Web account menu DOM" detail:detail?:@"" url:self.webView.URL]; return; }
        if([type isEqual:@"native-drawer-trace"]){ NSString *stage=[m.body[@"stage"] isKindOfClass:NSString.class]?m.body[@"stage"]:@"unknown"; NSString *error=[m.body[@"error"] isKindOfClass:NSString.class]?m.body[@"error"]:@""; [[DiagnosticsStore shared] addEvent:@"Native drawer bridge trace" detail:[NSString stringWithFormat:@"JS stage=%@%@",stage,error.length?[NSString stringWithFormat:@" error=%@",error]:@""] url:self.webView.URL]; return; }
        if([type isEqual:@"native-drawer"]){ BOOL enabled=[[NSUserDefaults standardUserDefaults] boolForKey:SXNativeUIKey]; [[DiagnosticsStore shared] addEvent:@"Native drawer bridge trace" detail:[NSString stringWithFormat:@"native-drawer message received; setting=%@",enabled?@"ON":@"OFF"] url:self.webView.URL]; if(enabled)[self openNativeDrawer]; return; }
    }
}

- (void)captureAccountDiagnostics {
    [[DiagnosticsStore shared] addEvent:@"Native drawer account trace" detail:@"captureAccountDiagnostics entered; starting JavaScript" url:self.webView.URL];
    NSString *script=@"(function(){function desc(el){if(!el)return null;var attrs={};Array.from(el.attributes||[]).forEach(function(a){if(a.name==='class'||a.name==='style')return;attrs[a.name]=a.value;});var imgs=Array.from(el.querySelectorAll?el.querySelectorAll('img'):[]).slice(0,8).map(function(i){return {src:i.currentSrc||i.src||'',alt:i.alt||''};});return {tag:el.tagName||'',attrs:attrs,text:(el.innerText||'').trim().slice(0,1200),html:(el.outerHTML||'').slice(0,6000),images:imgs};}var selectors=['[data-testid=DashButton_ProfileIcon_Link]'];var found={};selectors.forEach(function(s){found[s]=desc(document.querySelector(s));});var dialogs=Array.from(document.querySelectorAll('[role=dialog],[role=menu]')).slice(-4).map(desc);return {url:location.href,found:found,dialogs:dialogs};})()";
    [self.webView evaluateJavaScript:script completionHandler:^(id result,NSError *error){ if(error)return; NSData *data=[NSJSONSerialization dataWithJSONObject:result?:@{} options:NSJSONWritingPrettyPrinted error:nil]; NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[result description]; [[DiagnosticsStore shared] addEvent:@"Native drawer account DOM" detail:detail?:@"" url:self.webView.URL]; }];
}

- (void)presentNativeDrawerWithProfileData:(NSDictionary *)profileData {
    dispatch_async(dispatch_get_main_queue(),^{
        self.nativeDrawer=[NativeDrawerViewController new];
        self.nativeDrawer.delegate=self;
        self.nativeDrawer.profileData=profileData?:@{};
        [self.nativeDrawer presentInParent:self];
    });
}

- (void)openNativeDrawer {
    if(self.nativeDrawer.parentViewController)return;
    [[DiagnosticsStore shared] addEvent:@"Native drawer account trace" detail:@"openNativeDrawer entered" url:self.webView.URL];
    NSString *openScript=@"(function(){var b=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');if(!b)return false;window.__scarletXNativeBypass=true;try{b.click();return true;}catch(e){window.__scarletXNativeBypass=false;return false;}})()";
    __weak typeof(self) weakSelf=self;
    [self.webView evaluateJavaScript:openScript completionHandler:^(id opened,NSError *openError){
        typeof(self) self=weakSelf; if(!self)return;
        if(openError||![opened boolValue]){
            NSString *fallback=@"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var img=p&&p.querySelector('img');var label=p?(p.getAttribute('aria-label')||''):'';var name=label.replace(/^プロフィールメニュー\\s*/, '');window.__scarletXNativeBypass=false;return {avatarURL:img?(img.currentSrc||img.src||''):'',name:name,handle:'',following:'',followers:'',accounts:[]};})()";
            [self.webView evaluateJavaScript:fallback completionHandler:^(id result,NSError *error){ [self presentNativeDrawerWithProfileData:[result isKindOfClass:NSDictionary.class]?result:@{}]; }];
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.30*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            NSString *extract=@"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var dialog=Array.from(document.querySelectorAll('[role=dialog]')).find(function(d){return d.querySelector('[aria-label=\\\"アカウント\\\"]');})||document.querySelector('[role=dialog]');var label=p?(p.getAttribute('aria-label')||''):'';var name=label.replace(/^プロフィールメニュー\\s*/, '');var currentLink=dialog&&dialog.querySelector('[aria-label=\\\"アカウント\\\"] a[href^=\\\"/\\\"]');var path=currentLink?(currentLink.getAttribute('href')||''):'';var handle=(path&&path.indexOf('/',1)<0&&path!='/account/switch')?'@'+path.slice(1):'';var currentImg=(currentLink&&currentLink.querySelector('img'))||(p&&p.querySelector('img'));var text=dialog?(dialog.innerText||''):'';var fm=text.match(/([0-9.,万KkMm]+)\\s*フォロー中/);var frm=text.match(/([0-9.,万KkMm]+)\\s*フォロワー/);var accounts=[];if(dialog){Array.from(dialog.querySelectorAll('button[aria-label$=\\\"に切り替える\\\"]')).forEach(function(b){var l=b.getAttribute('aria-label')||'';var h=l.replace(/に切り替える$/,'');var im=b.querySelector('img');accounts.push({handle:h,avatarURL:im?(im.currentSrc||im.src||''):''});});}var result={avatarURL:currentImg?(currentImg.currentSrc||currentImg.src||''):'',name:name,handle:handle,following:fm?fm[1]:'',followers:frm?frm[1]:'',accounts:accounts};if(p&&p.getAttribute('aria-expanded')==='true'){try{p.click();}catch(e){}}window.__scarletXNativeBypass=false;return result;})()";
            [self.webView evaluateJavaScript:extract completionHandler:^(id result,NSError *error){
                typeof(self) self=weakSelf; if(!self)return;
                if(error)[[DiagnosticsStore shared] addError:@"Native drawer account extraction failed" error:error url:self.webView.URL];
                else { NSData *data=[NSJSONSerialization dataWithJSONObject:result?:@{} options:0 error:nil]; NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:@""; [[DiagnosticsStore shared] addEvent:@"Native drawer account data" detail:detail url:self.webView.URL]; }
                [self presentNativeDrawerWithProfileData:[result isKindOfClass:NSDictionary.class]?result:@{}];
            }];
        });
    }];
}

- (void)nativeDrawer:(NativeDrawerViewController*)drawer didSelectPath:(NSString*)path { NSURL*url=[NSURL URLWithString:[@"https://x.com" stringByAppendingString:path]]; [self loadURL:url reason:@"Native drawer"]; }
- (void)nativeDrawerDidSelectScarletSettings:(NativeDrawerViewController*)drawer{[self openSettings];}
- (void)openSettings { UINavigationController*nav=[[UINavigationController alloc] initWithRootViewController:[SettingsViewController new]]; nav.modalPresentationStyle=UIModalPresentationPageSheet; [self presentViewController:nav animated:YES completion:nil]; }
- (void)webView:(WKWebView*)w didStartProvisionalNavigation:(WKNavigation*)n {self.navigationStartTime=CACurrentMediaTime();self.navigationSession++;self.requestPending=NO;}
- (void)webView:(WKWebView*)w didFinishNavigation:(WKNavigation*)n {}
- (void)webView:(WKWebView*)w didFailProvisionalNavigation:(WKNavigation*)n withError:(NSError*)e {[[DiagnosticsStore shared] addError:@"Provisional navigation failed" error:e url:w.URL];}
- (void)webView:(WKWebView*)w didFailNavigation:(WKNavigation*)n withError:(NSError*)e {if([e.domain isEqual:NSURLErrorDomain]&&e.code==NSURLErrorCancelled)return;[[DiagnosticsStore shared] addError:@"Navigation failed" error:e url:w.URL];}
- (void)webViewWebContentProcessDidTerminate:(WKWebView*)w {[[DiagnosticsStore shared] addEvent:@"Web content process terminated" detail:@"" url:w.URL];}
- (void)webView:(WKWebView*)w decidePolicyForNavigationAction:(WKNavigationAction*)a decisionHandler:(void(^)(WKNavigationActionPolicy))d {NSURL*u=a.request.URL;NSString*s=u.scheme.lowercaseString;if([self isWebURL:u]||[s isEqual:@"about"]||[s isEqual:@"blob"]||[s isEqual:@"data"]){d(WKNavigationActionPolicyAllow);return;}d(WKNavigationActionPolicyCancel);}
- (WKWebView*)webView:(WKWebView*)w createWebViewWithConfiguration:(WKWebViewConfiguration*)c forNavigationAction:(WKNavigationAction*)a windowFeatures:(WKWindowFeatures*)f {if(a.targetFrame==nil&&a.request.URL)[w loadRequest:a.request];return nil;}
@end
