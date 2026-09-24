#import "DiagnosticsScripts.h"

@implementation DiagnosticsScripts
+ (void)installFlagsInto:(WKUserContentController *)contentController {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL resourcesDiagnostics = [defaults boolForKey:@"ScarletXDiagResources"];
    BOOL menuDiagnostics = [defaults boolForKey:@"ScarletXDiagMenu"];
    BOOL requestDiagnostics = [defaults boolForKey:@"ScarletXDiagRequests"];
    BOOL displayDiagnostics = [defaults boolForKey:@"ScarletXDiagDisplayDOM"];
    BOOL headerStateDiagnostics = [defaults boolForKey:@"ScarletXDiagHeaderState"];
    BOOL headerVisualDiagnostics = [defaults boolForKey:@"ScarletXDiagHeaderVisual"];
    BOOL topNavTransformDiagnostics = [defaults boolForKey:@"ScarletXDiagTopNavTransform"];
    BOOL paintProbeDiagnostics = [defaults boolForKey:@"ScarletXDiagPaintProbe"];
    BOOL accountInternalsDiagnostics = displayDiagnostics;
    NSString *diagnosticFlagSource = [NSString stringWithFormat:@"window.__scarletXDiagnostics={resources:%@,menu:%@,requests:%@,display:%@,headerState:%@,headerVisual:%@,topNavTransform:%@,paintProbe:%@,accountInternals:%@};", resourcesDiagnostics ? @"true" : @"false", menuDiagnostics ? @"true" : @"false", requestDiagnostics ? @"true" : @"false", displayDiagnostics ? @"true" : @"false", headerStateDiagnostics ? @"true" : @"false", headerVisualDiagnostics ? @"true" : @"false", topNavTransformDiagnostics ? @"true" : @"false", paintProbeDiagnostics ? @"true" : @"false", accountInternalsDiagnostics ? @"true" : @"false"];
    WKUserScript *diagnosticFlagScript = [[WKUserScript alloc] initWithSource:diagnosticFlagSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [contentController addUserScript:diagnosticFlagScript];

    NSString *accountScript = @"(function(){if(window.__scarletXAccountDiag)return;window.__scarletXAccountDiag=true;function snap(label){if(!((window.__scarletXDiagnostics||{}).accountInternals))return;try{var p=document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]');var layers=Array.from(document.querySelectorAll('[role=\\\"dialog\\\"],[role=\\\"menu\\\"]')).slice(0,8).map(function(d){return {role:d.getAttribute('role')||'',text:(d.innerText||'').replace(/\\s+/g,' ').trim().slice(0,700),images:Array.from(d.querySelectorAll('img')).map(function(x){return x.src;}).slice(0,12)};});window.webkit.messageHandlers.scarletx.postMessage({type:'performance',stage:'account-internals-snapshot',now:Math.round(performance.now()),extra:{label:label,url:location.href,profile:p?{aria:p.getAttribute('aria-label')||'',expanded:p.getAttribute('aria-expanded')||'',images:Array.from(p.querySelectorAll('img')).map(function(x){return x.src;}).slice(0,6)}:null,layers:layers}});}catch(e){}}document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p)return;snap('profile-click-before');setTimeout(function(){snap('profile-click-after-100');},100);setTimeout(function(){snap('profile-click-after-500');},500);setTimeout(function(){snap('profile-click-after-1500');},1500);},true);setTimeout(function(){snap('initial-1500');},1500);})();";
    WKUserScript *accountDiagnosticScript = [[WKUserScript alloc] initWithSource:accountScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [contentController addUserScript:accountDiagnosticScript];
}
@end
