#import "BrowserViewController.h"
#import <objc/runtime.h>

@interface BrowserViewController (InternalProfileAPIFiberRecoveryFix210)
- (NSString *)sx_internalProfileAPI_fiberRecoveryScript_fix210;
@end

@implementation BrowserViewController (InternalProfileAPIFiberRecoveryFix210)

+ (void)load {
    Class cls = self;
    SEL targetSEL = @selector(sx_internalProfileAPI_fiberRecoveryScript);
    Method target = class_getInstanceMethod(cls, targetSEL);
    Method replacement = class_getInstanceMethod(cls, @selector(sx_internalProfileAPI_fiberRecoveryScript_fix210));
    if (target && replacement) {
        class_replaceMethod(cls,
                            targetSEL,
                            method_getImplementation(replacement),
                            method_getTypeEncoding(target));
    }
}

- (NSString *)sx_internalProfileAPI_fiberRecoveryScript_fix210 {
    return @"(function(){"
    "function post(o){try{window.webkit.messageHandlers.scarletxInternalProfileAPI.postMessage(o);}catch(_){}}"
    "function fiberOf(n){if(!n)return null;var ks=[];try{ks=Object.keys(n);}catch(_){return null;}for(var i=0;i<ks.length;i++)if(ks[i].indexOf('__reactFiber$')===0)return n[ks[i]];return null;}"
    "function addUnique(a,v){if(!v||typeof v!=='object')return;if(a.indexOf(v)<0)a.push(v);}"
    "var unsafeValues=0,unsafeStoreGetters=0;"
    "function safeDataGet(obj,key){"
      "if(!obj||(typeof obj!=='object'&&typeof obj!=='function'))return undefined;"
      "var p=obj,depth=0;"
      "while(p&&depth<6){"
        "var d=null;"
        "try{d=Object.getOwnPropertyDescriptor(p,key);}catch(_e){unsafeValues++;return undefined;}"
        "if(d){"
          "if(Object.prototype.hasOwnProperty.call(d,'value'))return d.value;"
          "if(typeof d.get==='function'){if(key==='store')unsafeStoreGetters++;else unsafeValues++;return undefined;}"
          "return undefined;"
        "}"
        "try{p=Object.getPrototypeOf(p);}catch(_e){unsafeValues++;return undefined;}"
        "depth++;"
      "}"
      "return undefined;"
    "}"
    "try{"
      "var req=null,q=window.webpackChunk_twitter_responsive_web;"
      "if(!Array.isArray(q)){post({type:'fiber-recovery',stage:'no-webpack'});return;}"
      "var marker=940000000+Math.floor(Math.random()*50000000);q.push([[marker],{},function(r){req=r;}]);"
      "if(!req){post({type:'fiber-recovery',stage:'no-require'});return;}"
      "var atoms=null;try{atoms=req(302983);}catch(e){}"
      "var nodes=[];"
      "['[data-testid=primaryColumn]','[data-testid=DashButton_ProfileIcon_Link]','main','body'].forEach(function(s){try{var n=document.querySelector(s);if(n)nodes.push(n);}catch(_){}});"
      "try{Array.prototype.slice.call(document.querySelectorAll('article,[role=main] div')).slice(0,120).forEach(function(n){nodes.push(n);});}catch(_){ }"
      "var candidates=[],reduxStores=[],fiberCount=0,contextCount=0;"
      "for(var ni=0;ni<nodes.length;ni++){"
        "var f=fiberOf(nodes[ni]);"
        "for(var d=0;f&&d<120;d++,f=f.return){"
          "fiberCount++;"
          "var c=null;try{c=f.dependencies&&f.dependencies.firstContext;}catch(_){ }"
          "for(var ci=0;c&&ci<30;ci++){"
            "contextCount++;var vals=[];"
            "try{vals.push(c.memoizedValue);}catch(_){ }"
            "try{if(c.context){vals.push(c.context._currentValue);vals.push(c.context._currentValue2);}}catch(_){ }"
            "for(var vi=0;vi<vals.length;vi++){"
              "var v=vals[vi];"
              "if(!v||typeof v!=='object')continue;"
              "var vg=safeDataGet(v,'get'),vs=safeDataGet(v,'set'),vsub=safeDataGet(v,'sub');"
              "if(typeof vg==='function'&&typeof vs==='function'&&typeof vsub==='function')addUnique(candidates,v);"
              "var rs=v,storeValue=safeDataGet(v,'store');"
              "if(storeValue&&typeof storeValue==='object')rs=storeValue;"
              "var rget=safeDataGet(rs,'getState'),rdispatch=safeDataGet(rs,'dispatch'),rsubscribe=safeDataGet(rs,'subscribe');"
              "if(typeof rget==='function'&&typeof rdispatch==='function'&&typeof rsubscribe==='function')addUnique(reduxStores,rs);"
            "}"
            "try{c=c.next;}catch(_){break;}"
          "}"
        "}"
      "}"
      "var api=null,jotaiIndex=-1,atomExport='',atomKeys=[];"
      "try{atomKeys=atoms&&typeof atoms==='object'?Object.keys(atoms):[];}catch(_){unsafeValues++;atomKeys=[];}"
      "function tryAtom(store,index,key,atom){"
        "if(api||!atom)return;"
        "try{var getter=safeDataGet(store,'get');if(typeof getter!=='function')return;var x=getter.call(store,atom);if(x&&typeof safeDataGet(x,'withEndpoint')==='function'){api=x;jotaiIndex=index;atomExport=String(key||'');}}catch(_){unsafeValues++;}"
      "}"
      "for(var i=0;i<candidates.length&&!api;i++){"
        "if(atoms&&atoms.S9)tryAtom(candidates[i],i,'S9',atoms.S9);"
        "for(var ak=0;ak<atomKeys.length&&!api;ak++){var key=atomKeys[ak];if(key==='S9')continue;var atom=null;try{atom=atoms[key];}catch(_){unsafeValues++;continue;}if(atom&&(typeof atom==='object'||typeof atom==='function'))tryAtom(candidates[i],i,key,atom);}"
      "}"
      "var uid='',reduxSummary=[];"
      "for(var ri=0;ri<reduxStores.length;ri++){"
        "try{"
          "var getState=safeDataGet(reduxStores[ri],'getState');"
          "var st=typeof getState==='function'?getState.call(reduxStores[ri]):null;"
          "var session=st&&st.session;"
          "var s={index:ri,topKeys:st&&typeof st==='object'?Object.keys(st).slice(0,50):[],sessionKeys:session&&typeof session==='object'?Object.keys(session).slice(0,40):[]};"
          "reduxSummary.push(s);"
          "var vals=[session&&session.user_id,session&&session.userId,session&&session.user&&session.user.id_str,st&&st.loggedInUserId,st&&st.currentUserId];"
          "for(var ui=0;ui<vals.length;ui++){if(vals[ui]!=null&&String(vals[ui]).length){uid=String(vals[ui]);break;}}"
          "if(uid)break;"
        "}catch(_){unsafeValues++;}"
      "}"
      "post({type:'fiber-recovery',stage:'scan',fiberCount:fiberCount,contextCount:contextCount,jotaiCandidates:candidates.length,reduxCandidates:reduxStores.length,jotaiMatch:jotaiIndex,atomExport:atomExport,atomKeys:atomKeys.slice(0,80),apiFound:!!api,userId:uid,unsafeValues:unsafeValues,unsafeStoreGetters:unsafeStoreGetters,reduxSummary:reduxSummary});"
      "if(!api)return;"
      "window.__scarletXAPI=api;window.__scarletXAPICapturedAt=Date.now();"
      "var apiKeys=[];try{apiKeys=Object.keys(api).slice(0,80);}catch(_){unsafeValues++;}"
      "post({type:'api-captured-via-fiber',apiKeys:apiKeys,userId:uid,atomExport:atomExport});"
      "if(!uid)return;"
      "try{"
        "var epm=req(923288),factory=epm&&epm.Ay,withEndpoint=safeDataGet(api,'withEndpoint');"
        "var endpoint=typeof factory==='function'&&typeof withEndpoint==='function'?withEndpoint.call(api,factory):null;"
        "var fetchOriginals=endpoint&&safeDataGet(endpoint,'fetchUserOriginals');"
        "if(typeof fetchOriginals!=='function'){post({type:'fiber-fetch-error',stage:'endpoint',endpointKeys:endpoint&&typeof endpoint==='object'?Object.keys(endpoint).slice(0,80):[]});return;}"
        "post({type:'fiber-fetch-started',userId:uid,endpointKeys:Object.keys(endpoint).slice(0,80)});"
        "Promise.resolve(fetchOriginals.call(endpoint,{userId:uid,count:5,cursor:void 0,isPaymentsEnrolled:false,sortByMostLiked:false})).then(function(v){"
          "var json='';try{json=JSON.stringify(v);}catch(e){json='[JSON stringify failed: '+String(e)+']';}"
          "if(json.length>180000)json=json.slice(0,180000)+'...[truncated]';"
          "post({type:'fiber-fetch-success',userId:uid,resultType:typeof v,resultKeys:v&&typeof v==='object'?Object.keys(v).slice(0,80):[],resultJSON:json});"
        "}).catch(function(e){post({type:'fiber-fetch-error',stage:'request',userId:uid,message:String(e&&e.stack||e)});});"
      "}catch(e){post({type:'fiber-fetch-error',stage:'exception',userId:uid,message:String(e&&e.stack||e)});}"
    "}catch(e){post({type:'fiber-recovery',stage:'exception',message:String(e&&e.stack||e),unsafeValues:unsafeValues,unsafeStoreGetters:unsafeStoreGetters});}"
    "})();";
}

@end
