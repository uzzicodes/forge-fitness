import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../build/web/forge-sw.js',import.meta.url),'utf8');
function worker(){
  const handlers={},entries=new Map(),names=new Map(),messages=[];
  const absolute=input=>new URL(typeof input==='string'?input:input.url,'https://localhost:8788').href;
  const cache={addAll:async requests=>{for(const r of requests)entries.set(absolute(r),new Response('cached: '+absolute(r)));},match:async request=>entries.get(absolute(request))};
  const caches={open:async name=>{names.set(name,cache);return cache;},keys:async()=>[...names.keys()],delete:async name=>names.delete(name)};
  class LocalRequest extends Request{constructor(input,options){super(absolute(input),options);}}
  vm.runInNewContext(source,{self:{location:{origin:'https://localhost:8788'},skipWaiting:async()=>{},clients:{claim:async()=>{},matchAll:async()=>[{postMessage:data=>messages.push(data)}]},addEventListener:(name,callback)=>handlers[name]=callback},caches,Request:LocalRequest,Response,URL,fetch:async()=>{throw new Error('network offline');}});
  return {handlers,entries,messages};
}
test('worker saves its application files before declaring offline ready',async()=>{
  const w=worker();let promise;w.handlers.install({waitUntil:p=>promise=p});await promise;
  assert(w.entries.has('https://localhost:8788/'));assert(w.entries.has('https://localhost:8788/main.dart.js'));
  assert([...w.entries.keys()].some(url=>url.endsWith('canvaskit.wasm')));
  w.handlers.activate({waitUntil:p=>promise=p});await promise;assert.equal(w.messages[0].type,'FORGE_OFFLINE_READY');
});
test('offline navigation uses cached app but AI requests bypass the cache',async()=>{
  const w=worker();let promise;w.handlers.install({waitUntil:p=>promise=p});await promise;
  w.handlers.fetch({request:{url:'https://localhost:8788/',method:'GET',mode:'navigate'},respondWith:p=>promise=p});assert.match(await (await promise).text(),/cached/);
  let handled=false;
  w.handlers.fetch({request:{url:'https://localhost:8788/api/analyze',method:'POST',mode:'cors'},respondWith:()=>handled=true});assert.equal(handled,false);
  w.handlers.fetch({request:{url:'https://localhost:8788/api/status',method:'GET',mode:'cors'},respondWith:()=>handled=true});assert.equal(handled,false);
});

