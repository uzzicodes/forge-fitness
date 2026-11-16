import {readdirSync,readFileSync,writeFileSync,statSync} from 'node:fs';
import {resolve,relative,sep} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve('build/web');
function walk(dir){return readdirSync(dir).flatMap(name=>{const path=resolve(dir,name);return statSync(path).isDirectory()?walk(path):[path];});}
const files=walk(root).filter(file=>!relative(root,file).split(sep).some(part=>part.startsWith('.'))&&!/forge-sw\.js$|flutter_service_worker\.js$|\.map$/.test(file)&&!relative(root,file).includes('skwasm'));
const hash=createHash('sha256');for(const file of files.sort()){hash.update(relative(root,file));hash.update(readFileSync(file));}
const version=hash.digest('hex').slice(0,16);
const urls=['/',...files.map(file=>'/'+relative(root,file).split(sep).join('/'))];
const source=`const CACHE='forge-offline-${version}';
const FILES=${JSON.stringify(urls)};
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
`;
writeFileSync(resolve(root,'forge-sw.js'),source);
console.log('Offline app cache prepared: '+files.length+' files, version '+version);

