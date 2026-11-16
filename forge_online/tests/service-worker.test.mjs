import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {serviceWorkerSource} from '../scripts/service-worker.mjs';
function fixture({offline=false,cachedRedirect=false}={}){
 const handlers={},calls=[],cached=new Response('public app shell',{headers:{'Content-Type':'text/html'}});
 Object.defineProperty(cached,'redirected',{value:cachedRedirect});
 const context={URL,Request,Response,Error,self:{location:{origin:'https://forge.test'},addEventListener:(name,fn)=>handlers[name]=fn},caches:{open:async()=>({match:async()=>cached.cloneWithRedirect?cached.cloneWithRedirect():cached})},fetch:async(url,options)=>{calls.push({url,options});if(offline)throw new Error('offline');return new Response('online app');}};
 vm.runInNewContext(serviceWorkerSource('test',[]),context);
 function event(path,mode='navigate'){let promise;handlers.fetch({request:{url:'https://forge.test'+path,method:'GET',mode,headers:new Headers()},respondWith:p=>promise=p});return promise;}
 return {event,calls};
}
test('authentication, root and recovery navigation remain native browser requests',()=>{
 const f=fixture();for(const path of ['/','/signin-with-chatgpt?return_to=/','/callback','/signout-with-chatgpt','/configure','/recover.html','/iphone'])assert.equal(f.event(path),undefined,path);assert.equal(f.calls.length,0);
});
test('app navigation fetches the canonical nonredirecting shell and rejects redirects',async()=>{
 const f=fixture();const response=await f.event('/fitness/index.html');assert.equal(await response.text(),'online app');assert.equal(f.calls[0].url,'/fitness/');assert.equal(f.calls[0].options.redirect,'error');assert.equal(f.calls[0].options.credentials,'same-origin');
});
test('offline app navigation strips redirect metadata retained by older caches',async()=>{
 const f=fixture({offline:true,cachedRedirect:true});const response=await f.event('/fitness/');assert.equal(response.redirected,false);assert.equal(response.status,200);assert.equal(await response.text(),'public app shell');
});
test('private APIs are never intercepted and recovery never clears account storage',()=>{
 const f=fixture();assert.equal(f.event('/api/state','cors'),undefined);
 const repair=readFileSync(new URL('../public/recover.html',import.meta.url),'utf8');assert(!/localStorage\.clear|indexedDB\.deleteDatabase|\.unregister\(|caches\.delete/.test(repair));assert.match(repair,/updateViaCache:'none'/);
 const manifest=JSON.parse(readFileSync(new URL('../public/fitness/manifest.json',import.meta.url)));assert.equal(manifest.start_url,'/fitness/');
});
