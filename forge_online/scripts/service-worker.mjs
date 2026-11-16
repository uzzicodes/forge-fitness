// Cache only public app files. Browser navigation owns authentication redirects.
export function serviceWorkerSource(version,urls){return `const CACHE='forge-cloud-${version}';const FILES=${JSON.stringify(urls)};
const APP='/fitness/';
// Cache.addAll can retain redirected:true for /fitness/index.html -> /fitness/.
// Rebuild public responses before returning them to Safari navigation requests.
async function cleanResponse(response){return response.redirected?new Response(await response.blob(),{status:response.status,statusText:response.statusText,headers:response.headers}):response;}
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);try{for(let i=0;i<FILES.length;i+=4)await cache.addAll(FILES.slice(i,i+4).map(url=>new Request(url,{cache:'reload'})));await self.skipWaiting();}catch(e){await caches.delete(CACHE);throw e;}})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith('forge-cloud-')&&key!==CACHE)await caches.delete(key);await self.clients.claim();for(const client of await self.clients.matchAll())client.postMessage({type:'FORGE_OFFLINE_READY'});})()));
self.addEventListener('message',event=>{if(event.data==='FORGE_CACHE_STATUS')event.source?.postMessage({type:'FORGE_OFFLINE_READY'});});
self.addEventListener('fetch',event=>{const request=event.request,url=new URL(request.url);if(request.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||url.pathname.startsWith('/signin-')||url.pathname.startsWith('/signout-')||url.pathname==='/callback'||url.pathname==='/configure'||url.pathname==='/forge-sw.js')return;
if(request.mode==='navigate'){
 // Root, auth, guides and recovery pages must keep native redirect handling.
 if(![APP,APP+'index.html'].includes(url.pathname))return;
 event.respondWith((async()=>{try{const response=await fetch(APP,{credentials:'same-origin',cache:'no-store',redirect:'error'});if(!response.ok)throw new Error('App unavailable');return cleanResponse(response);}catch{const cache=await caches.open(CACHE);const cached=await cache.match(APP,{ignoreVary:true})||await cache.match(APP+'index.html',{ignoreVary:true});return cached?cleanResponse(cached):Response.error();}})());return;
}
if(url.pathname.startsWith('/fitness/')||url.pathname.startsWith('/vision/')||(url.pathname.startsWith('/demos/')&&!request.headers.has('Range')))event.respondWith((async()=>{const cache=await caches.open(CACHE);return cleanResponse(await cache.match(request,{ignoreSearch:true,ignoreVary:true})||await fetch(request));})());});
`;}
