#import "BrowserViewController.h"
#import "../UI/NativeProfileViewController.h"
#import "../Diagnostics/DiagnosticsStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BrowserViewController (NativeProfileLoaderDiagnostics)
@end

@implementation BrowserViewController (NativeProfileLoaderDiagnostics)

static char SXProfileLoaderDiagnosticTargetKey;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls=self;
        SEL originalStart=@selector(sx_startOfficialProfilePostLoadForScreenName:userId:base:profile:sourceWebView:);
        SEL diagnosticStart=@selector(sx_diag_startOfficialProfilePostLoadForScreenName:userId:base:profile:sourceWebView:);
        Method m1=class_getInstanceMethod(cls,originalStart);
        Method m2=class_getInstanceMethod(cls,diagnosticStart);
        if(m1&&m2)method_exchangeImplementations(m1,m2);

        SEL originalFinish=@selector(sx_finishProfileLoader:);
        SEL diagnosticFinish=@selector(sx_diag_finishProfileLoader:);
        Method f1=class_getInstanceMethod(cls,originalFinish);
        Method f2=class_getInstanceMethod(cls,diagnosticFinish);
        if(f1&&f2)method_exchangeImplementations(f1,f2);
    });
}

- (void)sx_diag_startOfficialProfilePostLoadForScreenName:(NSString *)screenName userId:(NSString *)userId base:(NSDictionary *)base profile:(NativeProfileViewController *)profile sourceWebView:(WKWebView *)sourceWebView {
    [self sx_diag_startOfficialProfilePostLoadForScreenName:screenName userId:userId base:base profile:profile sourceWebView:sourceWebView];
    NSDictionary *target=@{@"screenName":screenName?:@"",@"userId":userId?:@""};
    objc_setAssociatedObject(self,&SXProfileLoaderDiagnosticTargetKey,target,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sx_diag_finishProfileLoader:(WKWebView *)loader {
    if(![loader isKindOfClass:WKWebView.class]){
        [self sx_diag_finishProfileLoader:loader];
        return;
    }

    NSDictionary *target=objc_getAssociatedObject(self,&SXProfileLoaderDiagnosticTargetKey);
    NSString *screen=[target[@"screenName"] isKindOfClass:NSString.class]?target[@"screenName"]:@"";
    NSString *uid=[target[@"userId"] isKindOfClass:NSString.class]?target[@"userId"]:@"";
    NSData *screenData=[NSJSONSerialization dataWithJSONObject:@[screen] options:0 error:nil];
    NSData *uidData=[NSJSONSerialization dataWithJSONObject:@[uid] options:0 error:nil];
    NSString *screenArray=screenData?[[NSString alloc] initWithData:screenData encoding:NSUTF8StringEncoding]:@"[\"\"]";
    NSString *uidArray=uidData?[[NSString alloc] initWithData:uidData encoding:NSUTF8StringEncoding]:@"[\"\"]";
    NSString *screenLiteral=screenArray.length>=2?[screenArray substringWithRange:NSMakeRange(1,screenArray.length-2)]:@"\"\"";
    NSString *uidLiteral=uidArray.length>=2?[uidArray substringWithRange:NSMakeRange(1,uidArray.length-2)]:@"\"\"";

    NSString *script=[NSString stringWithFormat:@"(function(){var targetScreen=%@,targetUid=%@;function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(e){}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}function asStore(v){if(!v||typeof v!=='object')return null;var s=(v.store&&typeof v.store==='object')?v.store:v;return(s&&typeof s.getState==='function'&&typeof s.dispatch==='function')?s:null;}function storeFromNode(n){var f=fiberOf(n);for(var d=0;f&&d<80;d++,f=f.return){var c=f.dependencies&&f.dependencies.firstContext;for(var i=0;c&&i<12;i++,c=c.next){var vals=[];try{vals.push(c.memoizedValue);}catch(e){}try{if(c.context){vals.push(c.context._currentValue2);vals.push(c.context._currentValue);}}catch(e){}for(var j=0;j<vals.length;j++){var s=asStore(vals[j]);if(s)return s;}}}return null;}function val(o,k){try{var v=o&&o[k];return(typeof v==='string'||typeof v==='number')?String(v):'';}catch(e){return '';}}var primary=document.querySelector('[data-testid=\\\"primaryColumn\\\"]');var store=storeFromNode(primary)||storeFromNode(document.querySelector('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'))||storeFromNode(document.body);var out={ready:String(document.readyState||''),title:String(document.title||''),path:String(location.pathname||''),href:String(location.href||''),primaryColumn:!!primary,main:!!document.querySelector('main'),articles:document.querySelectorAll('article[data-testid=\\\"tweet\\\"]').length,cells:document.querySelectorAll('[data-testid=\\\"cellInnerDiv\\\"]').length,progressbars:document.querySelectorAll('[role=\\\"progressbar\\\"]').length,bodyTextLength:document.body&&document.body.innerText?document.body.innerText.length:0,loginLinks:document.querySelectorAll('a[href*=\\\"/i/flow/login\\\"]').length,storeFound:!!store,targetScreen:String(targetScreen||''),targetUid:String(targetUid||'')};if(!store)return out;var state;try{state=store.getState();}catch(e){out.storeError=String(e&&e.message||e);return out;}try{out.stateKeys=Object.keys(state||{}).slice(0,30);}catch(e){}var users=state&&state.entities&&state.entities.users&&state.entities.users.entities;var entity=(targetUid&&users&&users[targetUid])?users[targetUid]:null;if(!entity&&users&&targetScreen){var uks=Object.keys(users);for(var ui=0;ui<uks.length;ui++){var ue=users[uks[ui]],ul=ue&&ue.legacy;var sn=val(ue,'screen_name')||val(ul,'screen_name');if(sn===targetScreen){entity=ue;out.resolvedUserKey=String(uks[ui]);break;}}}out.targetUserFound=!!entity;if(entity){var el=entity.legacy&&typeof entity.legacy==='object'?entity.legacy:entity;out.resolvedScreen=val(entity,'screen_name')||val(el,'screen_name');out.resolvedUserId=val(entity,'rest_id')||val(el,'id_str')||val(el,'user_id_str');}var root=state&&state.entities&&state.entities.tweets;var map=root&&root.entities&&typeof root.entities==='object'?root.entities:null;var owners=[],samples=[];if(map){var tks=Object.keys(map);out.tweetEntityCount=tks.length;for(var ti=0;ti<tks.length;ti++){var t=map[tks[ti]];if(!t||typeof t!=='object')continue;var tl=t.legacy&&typeof t.legacy==='object'?t.legacy:t;var owner=val(tl,'user_id_str')||val(tl,'user_id')||val(t,'user_id_str')||val(t,'user_id');if(owner&&owners.indexOf(owner)<0&&owners.length<12)owners.push(owner);if(samples.length<6)samples.push({id:val(t,'rest_id')||val(tl,'id_str')||String(tks[ti]),owner:owner,hasText:!!(val(tl,'full_text')||val(tl,'text')||val(t,'full_text')||val(t,'text'))});}}out.tweetOwners=owners;out.tweetSamples=samples;return out;})()",screenLiteral,uidLiteral];

    __weak typeof(self) weakSelf=self;
    [loader evaluateJavaScript:script completionHandler:^(id result,NSError *error){
        typeof(self) self=weakSelf;
        if(!self)return;
        if(error){
            [[DiagnosticsStore shared] addError:@"Native profile loader final diagnostic failed" error:error url:loader.URL];
        } else if([result isKindOfClass:NSDictionary.class]) {
            NSData *json=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
            NSString *detail=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:[result description];
            [[DiagnosticsStore shared] addEvent:@"Native profile loader final diagnostic" detail:detail?:@"{}" url:loader.URL];
        } else {
            [[DiagnosticsStore shared] addEvent:@"Native profile loader final diagnostic" detail:[NSString stringWithFormat:@"unexpectedResult=%@",result?:@"nil"] url:loader.URL];
        }
        [self sx_diag_finishProfileLoader:loader];
    }];
}

@end
