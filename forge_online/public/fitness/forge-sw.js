const CACHE='forge-offline-f6f78be532327681';
const FILES=["/","/assets/AssetManifest.bin","/assets/AssetManifest.bin.json","/assets/FontManifest.json","/assets/NOTICES","/assets/fonts/MaterialIcons-Regular.otf","/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf","/assets/shaders/ink_sparkle.frag","/assets/shaders/stretch_effect.frag","/canvaskit/canvaskit.js","/canvaskit/canvaskit.js.symbols","/canvaskit/canvaskit.wasm","/canvaskit/chromium/canvaskit.js","/canvaskit/chromium/canvaskit.js.symbols","/canvaskit/chromium/canvaskit.wasm","/canvaskit/wimp.js","/canvaskit/wimp.js.symbols","/canvaskit/wimp.wasm","/favicon.png","/flutter.js","/flutter_bootstrap.js","/icons/Icon-192.png","/icons/Icon-512.png","/icons/Icon-maskable-192.png","/icons/Icon-maskable-512.png","/index.html","/main.dart.js","/manifest.json","/version.json"];
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(CACHE);
  try{for(let i=0;i<FILES.length;i+=4){await cache.addAll(FILES.slice(i,i+4).map(url=>new Request(url,{cache:'reload'})));}await self.skipWaiting();}
  catch(error){await caches.delete(CACHE);throw error;}
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const name of await caches.keys()){if(name.startsWith('forge-offline-')&&name!==CACHE)await caches.delete(name);}
  await self.clients.claim();
  for(const client of await self.clients.matchAll())client.postMessage({type:'FORGE_OFFLINE_READY'});
})()));
self.addEventListener('message',event=>{if(event.data==='FORGE_CACHE_STATUS')event.source?.postMessage({type:'FORGE_OFFLINE_READY'});});
self.addEventListener('fetch',event=>{
  const req=event.request,url=new URL(req.url);
  if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||['/iphone','/forge-local-ca.cer','/forge-sw.js','/version.json'].includes(url.pathname))return;
  if(req.mode==='navigate'){
    event.respondWith(fetch(req).catch(async()=>{const cache=await caches.open(CACHE);return (await cache.match('/'))||Response.error();}));return;
  }
  event.respondWith((async()=>{const cache=await caches.open(CACHE);const saved=await cache.match(req);return saved||fetch(req);})());
});
