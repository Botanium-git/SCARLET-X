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
    BOOL accountInternalsDiagnostics = [defaults boolForKey:@"ScarletXDiagAccountInternals"];
    NSString *diagnosticFlagSource = [NSString stringWithFormat:@"window.__scarletXDiagnostics={resources:%@,menu:%@,requests:%@,display:%@,headerState:%@,headerVisual:%@,topNavTransform:%@,paintProbe:%@,accountInternals:%@};", resourcesDiagnostics ? @"true" : @"false", menuDiagnostics ? @"true" : @"false", requestDiagnostics ? @"true" : @"false", displayDiagnostics ? @"true" : @"false", headerStateDiagnostics ? @"true" : @"false", headerVisualDiagnostics ? @"true" : @"false", topNavTransformDiagnostics ? @"true" : @"false", paintProbeDiagnostics ? @"true" : @"false", accountInternalsDiagnostics ? @"true" : @"false"];
    WKUserScript *diagnosticFlagScript = [[WKUserScript alloc] initWithSource:diagnosticFlagSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [contentController addUserScript:diagnosticFlagScript];
}
@end
