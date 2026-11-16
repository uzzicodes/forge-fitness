// Isolated HTTP fixture: exercises real WebKit workers, never personal APIs.
import {createRequire} from 'node:module';
import http from 'node:http';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {serviceWorkerSource} from '../scripts/service-worker.mjs';
process.env.PLAYWRIGHT_BROWSERS_PATH='D:/forge_browser_qa';
const require=createRequire(import.meta.url),{webkit}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
let fixed=false,networkDown=false;
const old=`self.addEventListener('install',e=>e.waitUntil(caches.open('forge-cloud-old').then(c=>c.addAll(['/fitness/index.html'])).then(()=>self.skipWaiting())));self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));self.addEventListener('fetch',e=>{if(e.request.mode==='navigate')e.respondWith(fetch(e.request).catch(()=>caches.open('forge-cloud-old').then(c=>c.match('/fitness/index.html'))));});`;
const server=http.createServer((req,res)=>{
 const path=new URL(req.url,'http://local').pathname;
 if(networkDown && path.startsWith('/fitness/'))return req.socket.destroy();
 if(path==='/fitness/index.html'){res.writeHead(302,{Location:'/fitness/'});return res.end();}
 if(path==='/'){res.writeHead(302,{Location:'/signed-out'});return res.end();}
 if(path==='/forge-sw.js'){res.writeHead(200,{'Content-Type':'application/javascript','Cache-Control':'no-store'});return res.end(fixed?serviceWorkerSource('fixed',['/fitness/index.html']):old);}
 if(path==='/recover.html'){res.writeHead(200,{'Content-Type':'text/html','Cache-Control':'no-store'});return res.end(readFileSync('public/recover.html'));}
 res.writeHead(200,{'Content-Type':'text/html','Cache-Control':'no-store'});res.end(path==='/signed-out'?'<h1>Sign-in destination</h1>':'<h1>FORGE shell</h1>');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port;
const browser=await webkit.launch({headless:true}),context=await browser.newContext(),page=await context.newPage(),checks=[];
try{
 await page.goto(origin+'/fitness/');
 await page.evaluate(async()=>{localStorage.setItem('forge-test-pending','keep my unsynced workout');await navigator.serviceWorker.register('/forge-sw.js',{scope:'/'});await navigator.serviceWorker.ready;});
 await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
 assert.equal(await page.evaluate(async()=>{const c=await caches.open('forge-cloud-old');return (await c.match('/fitness/index.html')).redirected;}),true);
 networkDown=true;let oldFailure='';try{await page.goto(origin+'/fitness/');}catch(e){oldFailure=e.message;}
 assert(oldFailure,'Old worker must reproduce the failed offline navigation');checks.push('Old redirected cache reproduces a WebKit navigation failure');
 networkDown=false;fixed=true;
 await page.goto(origin+'/recover.html');await page.waitForURL(origin+'/fitness/',{timeout:90000});await page.getByText('FORGE shell',{exact:true}).waitFor();
 assert.equal(await page.evaluate(()=>localStorage.getItem('forge-test-pending')),'keep my unsynced workout');
 assert.match(await page.evaluate(async()=>{const r=await navigator.serviceWorker.getRegistration('/');return (await fetch(r.active.scriptURL)).text();}),/cleanResponse/);
 checks.push('Recovery replaces an installed old worker and preserves unsynced local storage');
 networkDown=true;await page.goto(origin+'/fitness/');await page.getByText('FORGE shell',{exact:true}).waitFor();checks.push('Fixed worker opens cached app offline in WebKit');
 networkDown=false;await page.goto(origin+'/');await page.waitForURL(origin+'/signed-out');await page.getByText('Sign-in destination',{exact:true}).waitFor();checks.push('Root authentication redirect remains native and reaches its destination');
 await page.goto(origin+'/fitness/index.html');await page.getByText('FORGE shell',{exact:true}).waitFor();checks.push('Legacy index.html shortcut opens the canonical app without redirect metadata');
 writeFileSync('qa/safari-startup-verification.json',JSON.stringify({engine:'Playwright WebKit 26.5 on Windows, not a physical iPhone',oldFailure,checks,completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
