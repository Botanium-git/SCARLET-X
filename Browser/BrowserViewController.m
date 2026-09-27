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
        NSString *bridge=@"(function(){if(window.__scarletXNativeDrawerInstalled)return;window.__scarletXNativeDrawerInstalled=true;window.__scarletXNativeBypass=false;try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'bridge-installed'});}catch(_){}document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p||window.__scarletXNativeBypass||!e.isTrusted)return;try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'profile-click-captured'});}catch(_){}e.preventDefault();e.stopPropagation();if(e.stopImmediatePropagation)e.stopImmediatePropagation();try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer'});}catch(err){try{window.webkit.messageHandlers.scarletx.postMessage({type:'native-drawer-trace',stage:'native-drawer-post-failed',error:String(err)});}catch(_){} }},true);})();";
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
        if([type isEqual:@"performance"]){
            NSString *stage=[m.body[@"stage"] isKindOfClass:NSString.class]?m.body[@"stage"]:@"";
            if([stage isEqual:@"follower-count-probe"]||[stage isEqual:@"follower-count-probe-error"]){
                id extra=m.body[@"extra"]?:@{};
                NSData *data=[NSJSONSerialization dataWithJSONObject:extra options:0 error:nil];
                NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[extra description];
                [[DiagnosticsStore shared] addEvent:@"Passive follower probe" detail:detail?:@"" url:self.webView.URL];
            }
            return;
        }
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
    [[DiagnosticsStore shared] addEvent:@"Native drawer account trace" detail:@"openNativeDrawer entered; reading Redux store directly" url:self.webView.URL];
    NSString *extract=@"(function(){var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++){if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];}return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return (s&&typeof s.getState==='function'&&typeof s.subscribe==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<70;d++,f=f.return){var deps=null;try{deps=f.dependencies;}catch(e){}var c=deps&&deps.firstContext;for(var i=0;c&&i<10;i++){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{var ctx=c.context;if(ctx&&typeof ctx==='object'){vals.push(ctx._currentValue2);vals.push(ctx._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}try{c=c.next;}catch(e){break;}}var direct=asStore(f.memoizedProps);if(direct)return direct;}return null;}function firstString(root,key){var seen=new Set(),found='';function walk(v,depth){if(found||!v||typeof v!=='object'||seen.has(v)||depth>5)return;seen.add(v);try{var x=v[key];if(typeof x==='string'&&x.length&&x.length<1000){found=x;return;}}catch(e){}var ks=[];try{ks=Object.keys(v);}catch(e){return;}for(var i=0;i<Math.min(ks.length,70);i++){var k=ks[i];if(k==='window'||k==='document'||k==='ownerDocument'||k==='parentNode'||k==='childNodes')continue;var x;try{x=v[k];}catch(e){continue;}if(x&&typeof x==='object')walk(x,depth+1);if(found)return;}}walk(root,0);return found;}function imageProbe(root){var out={topKeys:[],imageKeys:[],imageCandidates:[]},seen=new Set();try{if(root&&typeof root==='object')out.topKeys=Object.keys(root).slice(0,80);}catch(e){}function walk(v,path,depth){if(!v||typeof v!=='object'||seen.has(v)||depth>6||out.imageCandidates.length>=24)return;seen.add(v);var ks=[];try{ks=Object.keys(v);}catch(e){return;}for(var i=0;i<Math.min(ks.length,90);i++){var k=ks[i],x;try{x=v[k];}catch(e){continue;}var kp=path?path+'.'+k:k;if(/image|avatar|photo|picture|profile/i.test(k)&&out.imageKeys.indexOf(k)<0&&out.imageKeys.length<40)out.imageKeys.push(k);if(typeof x==='string'&&x.length<2000&&(/profile_images|twimg\\.com|pbs\\.twimg|avatar|image/i.test(x)||/image|avatar|photo|picture|profile/i.test(k))){out.imageCandidates.push({path:kp,key:k,value:x});if(out.imageCandidates.length>=24)return;}if(x&&typeof x==='object')walk(x,kp,depth+1);}}walk(root,'root',0);return out;}var img=p&&p.querySelector('img');var label=p?(p.getAttribute('aria-label')||''):'';var labelName=label.replace(/^プロフィールメニュー\\s*/, '');var href=p?(p.getAttribute('href')||''):'';if(!href&&p&&p.closest){var a=p.closest('a[href]');href=a?(a.getAttribute('href')||''):'';}var currentScreen=(/^\\/[A-Za-z0-9_]+$/.test(href))?href.slice(1):'';var store=storeFromNode(p)||storeFromNode(document.querySelector('[data-testid=primaryColumn]'))||storeFromNode(document.body);if(!store){return {source:'fallback-no-store',avatarURL:img?(img.currentSrc||img.src||''):'',name:labelName,handle:currentScreen?'@'+currentScreen:'',following:'',followers:'',accounts:[]};}var state=null;try{state=store.getState();}catch(e){}var users=state&&state.multiAccount&&Array.isArray(state.multiAccount.users)?state.multiAccount.users:[];var mapped=users.map(function(u){return {userId:firstString(u,'user_id')||firstString(u,'rest_id'),screenName:firstString(u,'screen_name'),name:firstString(u,'name'),avatarURL:firstString(u,'avatar_image_url')||firstString(u,'profile_image_url_https'),imageProbe:imageProbe(u)};}).filter(function(u){return !!(u.screenName||u.name||u.avatarURL);});var current=null;if(currentScreen)current=mapped.find(function(u){return u.screenName===currentScreen;})||null;if(!current&&labelName){var same=mapped.filter(function(u){return u.name===labelName;});if(same.length===1)current=same[0];}var accounts=mapped.filter(function(u){return !current||u!==current;}).map(function(u){return {handle:u.screenName?'@'+u.screenName:'',avatarURL:u.avatarURL||''};});var userImageProbe=mapped.map(function(u){return {screenName:u.screenName,name:u.name,avatarURL:u.avatarURL,imageProbe:u.imageProbe};});var entitiesUsers=state&&state.entities&&state.entities.users;var entityMap=entitiesUsers&&entitiesUsers.entities&&typeof entitiesUsers.entities==='object'?entitiesUsers.entities:null;var currentId=current&&current.userId?current.userId:'';var probeScreen=(current&&current.screenName)||currentScreen;var entityHit=null,entityPath='';if(entityMap&&currentId&&entityMap[currentId]&&typeof entityMap[currentId]==='object'){entityHit=entityMap[currentId];entityPath='state.entities.users.entities['+currentId+']';}if(!entityHit&&entityMap&&probeScreen){var ekeys=[];try{ekeys=Object.keys(entityMap);}catch(e){}for(var ei=0;ei<ekeys.length;ei++){var ev;try{ev=entityMap[ekeys[ei]];}catch(e){continue;}if(!ev||typeof ev!=='object')continue;var sn=firstString(ev,'screen_name');if(sn===probeScreen){entityHit=ev;entityPath='state.entities.users.entities['+ekeys[ei]+']';break;}}}var followerProbe={currentUserId:currentId,currentScreen:probeScreen,entitiesUsersPresent:!!entitiesUsers,entitiesMapPresent:!!entityMap,matched:!!entityHit,matchPath:entityPath};if(entityHit){var legacy=null;try{legacy=(entityHit.legacy&&typeof entityHit.legacy==='object')?entityHit.legacy:null;}catch(e){}followerProbe.identity={user_id:firstString(entityHit,'user_id'),rest_id:firstString(entityHit,'rest_id'),screen_name:firstString(entityHit,'screen_name'),name:firstString(entityHit,'name')};followerProbe.counts={};['followers_count','friends_count','following_count'].forEach(function(k){try{var v=entityHit[k];if(typeof v==='number')followerProbe.counts[k]=v;}catch(e){}});if(legacy){['followers_count','friends_count','following_count'].forEach(function(k){try{var v=legacy[k];if(typeof v==='number')followerProbe.counts['legacy.'+k]=v;}catch(e){}});}try{followerProbe.keys=Object.keys(entityHit).slice(0,80);}catch(e){followerProbe.keys=[];}try{followerProbe.legacyKeys=legacy?Object.keys(legacy).slice(0,80):[];}catch(e){followerProbe.legacyKeys=[];}}return {source:'redux-store',avatarURL:(current&&current.avatarURL)||(img?(img.currentSrc||img.src||''):''),name:(current&&current.name)||labelName,handle:(current&&current.screenName)?'@'+current.screenName:(currentScreen?'@'+currentScreen:''),following:'',followers:'',accounts:accounts,reduxUserCount:mapped.length,userImageProbe:userImageProbe,followerProbe:followerProbe};})()";
    __weak typeof(self) weakSelf=self;
    [self.webView evaluateJavaScript:extract completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf; if(!self)return;
        if(error){
            [[DiagnosticsStore shared] addError:@"Native drawer Redux extraction failed" error:error url:self.webView.URL];
        } else {
            NSData *data=[NSJSONSerialization dataWithJSONObject:result?:@{} options:0 error:nil];
            NSString *detail=data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:@"";
            [[DiagnosticsStore shared] addEvent:@"Native drawer Redux account data" detail:detail url:self.webView.URL];
        }
        [self presentNativeDrawerWithProfileData:[result isKindOfClass:NSDictionary.class]?result:@{}];
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
