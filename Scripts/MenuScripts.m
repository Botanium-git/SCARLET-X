#import "MenuScripts.h"

@implementation MenuScripts

+ (NSString *)menuProbeScript {
    return @"";
}

+ (NSString *)menuWarmupScript {
    return @"document.addEventListener('click',function(e){var p=e.target&&e.target.closest?e.target.closest('[data-testid=\\\"DashButton_ProfileIcon_Link\\\"]'):null;if(!p||!e.isTrusted)return;setTimeout(function(){try{var k=Object.keys(p).find(function(x){return x.indexOf('__reactFiber$')===0;});var f=k?p[k]:null,store=null;for(var d=0;f&&d<70&&!store;d++,f=f.return){var c=f.dependencies&&f.dependencies.firstContext;for(var i=0;c&&i<10;i++,c=c.next){var v=c.memoizedValue;if(v&&v.store&&typeof v.store.getState==='function'){store=v.store;break;}}}if(!store){send('follower-count-probe',{found:false,reason:'store-not-found'});return;}var s=store.getState();var u=s&&s.entities&&s.entities.users;var out={found:true,usersKeys:u&&typeof u==='object'?Object.keys(u).slice(0,40):[]};if(u&&u.entities&&typeof u.entities==='object'){out.entityCount=Object.keys(u.entities).length;}send('follower-count-probe',out);}catch(err){send('follower-count-probe-error',{message:String(err)});}},0);},true);";
}

@end
