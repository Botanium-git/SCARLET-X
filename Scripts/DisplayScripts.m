#import "DisplayScripts.h"

@implementation DisplayScripts
+ (void)installSettingsScriptInto:(WKUserContentController *)contentController {
    NSString *settingsScript = @"(function(){"
        "if(window.__scarletXSettingsInstalled)return;"
        "window.__scarletXSettingsInstalled=true;"
        "function add(){"
          "if(document.getElementById('scarletx-settings-item'))return;"
          "var candidates=[].slice.call(document.querySelectorAll('a[href=\"/settings\"],a[href=\"/settings/account\"]'));"
          "var anchor=candidates.find(function(a){return (a.innerText||'').indexOf('設定とプライバシー')!==-1;})||candidates[0];"
          "if(!anchor)return;"
          "var row=anchor.parentElement;"
          "var list=row&&row.parentElement;"
          "if(!row||!list)return;"
          "var item=row.cloneNode(true);"
          "item.id='scarletx-settings-item';"
          "var link=item.querySelector('a[href=\"/settings\"],a[href=\"/settings/account\"]')||(item.matches&&item.matches('a')?item:null);"
          "if(link){link.removeAttribute('href');link.setAttribute('role','button');}"
          "var walker=document.createTreeWalker(item,NodeFilter.SHOW_TEXT);"
          "var node;"
          "while((node=walker.nextNode())){if(node.nodeValue&&node.nodeValue.indexOf('設定とプライバシー')!==-1){node.nodeValue=node.nodeValue.replace('設定とプライバシー','Scarlet X 設定');break;}}"
          "item.addEventListener('click',function(e){e.preventDefault();e.stopPropagation();window.webkit.messageHandlers.scarletx.postMessage('settings');},true);"
          "list.insertBefore(item,row.nextSibling);"
        "}"
        "new MutationObserver(add).observe(document.documentElement,{childList:true,subtree:true});"
        "add();"
      "})();";
    WKUserScript *script = [[WKUserScript alloc] initWithSource:settingsScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [contentController addUserScript:script];
}

+ (void)installDisplayCustomizationInto:(WKUserContentController *)contentController {
    NSUserDefaults *displayDefaults = [NSUserDefaults standardUserDefaults];
    BOOL (^displayOption)(NSString *) = ^BOOL(NSString *key) {
        return [displayDefaults objectForKey:key] ? [displayDefaults boolForKey:key] : YES;
    };
    NSString *displayFlags = [NSString stringWithFormat:
        @"window.__scarletXDisplay={appDownload:%@,purchase:%@,unverified:%@,grok:%@,followingOnly:%@};",
        displayOption(@"ScarletXHideAppDownload") ? @"true" : @"false",
        displayOption(@"ScarletXHidePurchase") ? @"true" : @"false",
        displayOption(@"ScarletXHideUnverifiedCard") ? @"true" : @"false",
        displayOption(@"ScarletXHideGrok") ? @"true" : @"false",
        displayOption(@"ScarletXFollowingOnly") ? @"true" : @"false"];
    [contentController addUserScript:[[WKUserScript alloc] initWithSource:displayFlags injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];

    NSString *displayCustomizationScript = @"(function(){"
      "if(window.__scarletXDisplayInstalled)return;window.__scarletXDisplayInstalled=true;"
      "function hide(el){if(el)el.style.setProperty('display','none','important');}"
      "function apply(root){var f=window.__scarletXDisplay||{};var scope=root&&root.querySelectorAll?root:document;"
        "if(f.appDownload){Array.from(scope.querySelectorAll('a[href*=\"apps.apple.com\"]')).forEach(function(a){if((a.href||'').indexOf('id333903271')>=0)hide(a.parentElement||a);});}"
        "if(f.purchase){Array.from(scope.querySelectorAll('a[href=\"/i/premium_sign_up\"]')).forEach(function(a){if((a.innerText||'').trim()==='購入する')hide(a);});}"
        "if(f.grok){Array.from(scope.querySelectorAll('a[href=\"/i/grok\"]')).forEach(hide);}"
        "if(f.followingOnly&&location.pathname==='/home'){var tabs=Array.from(document.querySelectorAll('[role=tab]'));var following=tabs.find(function(t){return (t.innerText||'').trim()==='フォロー中';});var forYou=tabs.find(function(t){return (t.innerText||'').trim()==='おすすめ';});if(following&&forYou){if(following.getAttribute('aria-selected')!=='true')following.click();else{var list=following.closest('[role=tablist][data-testid=ScrollSnap-List]');if(list&&list.contains(forYou)){var swipe=list.parentElement;var inner=swipe&&swipe.parentElement;var nav=inner&&inner.parentElement;var navWrap=nav&&nav.parentElement;var row=navWrap&&navWrap.parentElement;if(swipe&&swipe.getAttribute('data-testid')==='ScrollSnap-SwipeableList'&&nav&&nav.tagName==='NAV'&&nav.getAttribute('role')==='navigation'&&row&&row.contains(list)&&row.children.length===2)hide(row);else hide(list);}}}}"
        "if(f.unverified){Array.from(scope.querySelectorAll('a[href=\"/i/premium_sign_up\"]')).forEach(function(a){var t=(a.innerText||'').trim();if(t.indexOf('認証される')<0)return;var p=a;for(var i=0;i<6&&p&&p!==document.body;i++,p=p.parentElement){var pt=(p.innerText||'').replace(/\\s+/g,' ').trim();if(pt.indexOf('まだ認証されていません')>=0&&pt.indexOf('認証される')>=0&&pt.length<500){hide(p);return;}}});}"
      "}"
      "apply(document);new MutationObserver(function(rs){rs.forEach(function(r){Array.from(r.addedNodes||[]).forEach(function(n){if(n&&n.nodeType===1){apply(n);apply(n.parentElement);}});});}).observe(document.documentElement,{childList:true,subtree:true});"
    "})();";
    [contentController addUserScript:[[WKUserScript alloc] initWithSource:displayCustomizationScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
}
@end
