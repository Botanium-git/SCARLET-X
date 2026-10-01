#import "BrowserViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileRequestProbe)
@end

@implementation BrowserViewController (NativeProfileRequestProbe)

static char SXProfileRequestProbeTargetKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls=self;
        SEL original=@selector(sx_finishProfileLoader:);
        SEL replacement=@selector(sx_requestProbe_finishProfileLoader:);
        Method m1=class_getInstanceMethod(cls,original);
        Method m2=class_getInstanceMethod(cls,replacement);
        if(m1&&m2) method_exchangeImplementations(m1,m2);
    });
}

- (void)sx_requestProbe_finishProfileLoader:(WKWebView *)loader {
    if(![loader isKindOfClass:WKWebView.class]) {
        [self sx_requestProbe_finishProfileLoader:loader];
        return;
    }

    NSString *script=@"(function(){var out={};try{var entries=performance.getEntriesByType('resource')||[];var seen={},api=[],graphql=[];for(var i=0;i<entries.length;i++){var n=String(entries[i]&&entries[i].name||'');if(!n)continue;var u;try{u=new URL(n,location.href);}catch(e){continue;}var p=String(u.pathname||'');if(p.indexOf('/i/api/graphql/')>=0||p.indexOf('/graphql/')>=0||p.indexOf('/api/')>=0){var safe=String(u.origin||'')+p;if(!seen[safe]){seen[safe]=1;api.push(safe);}if(p.indexOf('/i/api/graphql/')>=0){var parts=p.split('/').filter(Boolean);var idx=parts.indexOf('graphql');if(idx>=0&&parts.length>idx+2){graphql.push({queryId:String(parts[idx+1]||''),operation:String(parts[idx+2]||''),path:p});}}}}out.resourceCount=entries.length;out.apiPaths=api.slice(-80);out.graphql=graphql.slice(-40);}catch(e){out.performanceError=String(e&&e.message||e);}try{out.href=String(location.href||'');out.ready=String(document.readyState||'');out.articles=document.querySelectorAll('article[data-testid=\\\"tweet\\\"]').length;out.cells=document.querySelectorAll('[data-testid=\\\"cellInnerDiv\\\"]').length;}catch(e){}return out;})()";

    __weak typeof(self) weakSelf=self;
    [loader evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;
        if(!self)return;
        if(error){
            [[DiagnosticsStore shared] addError:@"Native profile request probe failed" error:error url:loader.URL];
        } else if([result isKindOfClass:NSDictionary.class]) {
            NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
            NSString *detail=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:[result description];
            [[DiagnosticsStore shared] addEvent:@"Native profile request probe" detail:detail?:@"{}" url:loader.URL];
        }
        [self sx_requestProbe_finishProfileLoader:loader];
    }];
}

@end
