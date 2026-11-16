import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173';
mkdirSync('qa',{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,isMobile:true,hasTouch:true}),page=await context.newPage(),errors=[];
page.setDefaultTimeout(15000);page.on('pageerror',e=>{errors.push(e.message);console.log('PAGE ERROR',e.message);});
page.on('requestfailed',r=>console.log('REQUEST FAILED',r.url(),r.failure()?.errorText));
async function enable(){await page.waitForSelector('flutter-view',{timeout:90000});const el=page.locator('flt-semantics-placeholder');if(await el.count())await el.evaluate(e=>e.click());await page.waitForTimeout(700);}
async function capture(name){writeFileSync('qa/'+name+'.txt',await page.locator('body').ariaSnapshot());await page.screenshot({path:'qa/'+name+'.png'});}
try{
 await page.goto(base+'/signin-with-chatgpt?return_to=/',{waitUntil:'networkidle'});await enable();
 let state=await (await context.request.get(base+'/api/state')).json();assert(state.records.some(r=>r.key==='profile'&&r.value?.name==='Test Athlete'));
 assert.match(await page.locator('body').ariaSnapshot(),/Hey, Test Athlete/);await capture('phone-dashboard');
 await page.getByRole('tab',{name:'Train',exact:true}).click();await page.waitForTimeout(350);await capture('phone-week');
 await page.getByRole('tab',{name:'Settings',exact:true}).click();await page.waitForTimeout(300);await capture('phone-settings');
 assert.equal(await page.getByRole('button',{name:'Sync now',exact:true}).count(),1);
 await page.getByRole('tab',{name:'Today',exact:true}).click();
 console.log('Phone layout and cloud hydration passed; checking service worker.');
 console.log(await page.evaluate(async()=>({secure:isSecureContext,controller:!!navigator.serviceWorker.controller,registrations:(await navigator.serviceWorker.getRegistrations()).map(r=>({scope:r.scope,active:r.active?.state,installing:r.installing?.state,waiting:r.waiting?.state}))})));
 await page.evaluate(async()=>{await Promise.race([navigator.serviceWorker.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Offline worker was not ready within 25 seconds')),25000))]);});
 await page.waitForFunction(()=>navigator.serviceWorker.controller!==null);
 const before=state.records.find(r=>r.key==='water:2026-10-27')?.value||0;
 await context.setOffline(true);
 for(let i=0;i<5&&!(await page.getByRole('button',{name:'Add 250 ml',exact:true}).count());i++){await page.mouse.move(250,400);await page.mouse.wheel(0,500);await page.waitForTimeout(150);}
 await page.getByRole('button',{name:'Add 250 ml',exact:true}).click();await page.waitForTimeout(900);
 console.log('Offline edit queued; reloading cached app.');
 await page.reload({waitUntil:'domcontentloaded'});await enable();await capture('phone-offline');
 const pending=await page.evaluate(()=>Object.entries(localStorage).find(([k])=>k.includes('forge.cloud.pending'))?.[1]);assert(pending&&pending.includes('water:2026-10-27'));
 await context.setOffline(false);
 console.log('Offline reload passed; reconnecting.');
 await page.getByRole('tab',{name:'Settings',exact:true}).click();await page.waitForTimeout(250);
 await page.getByRole('button',{name:'Sync now',exact:true}).click();await page.waitForTimeout(1200);
 state=await (await context.request.get(base+'/api/state')).json();assert.equal(state.records.find(r=>r.key==='water:2026-10-27')?.value,before+1);
 const fixture='data:image/jpeg;base64,'+readFileSync('downloads/food101-validation.jpg').toString('base64');
 const suggestions=await page.evaluate(async data=>JSON.parse(await window.forgeFoodSuggest(data)),fixture);
 const labels=JSON.parse(readFileSync('public/vision/labels.json')),meta=JSON.parse(readFileSync('downloads/fixture-meta.json'));
 const expected=labels[meta.label].replaceAll('_',' ');
 assert.equal(suggestions.length,4);assert(suggestions.some(s=>s.name===expected));assert(suggestions.every(s=>typeof s.name==='string'&&Number.isFinite(s.score)));writeFileSync('qa/classifier-smoke.json',JSON.stringify({dataset:meta.dataset,split:meta.split,row:meta.row,expected,suggestions,note:'One real supported-food sample, not a broad accuracy benchmark'},null,2));
 assert.equal(errors.length,0);console.log('PASS: phone viewport, account sync, week view, offline reload, queued edit, reconnect and real browser photo-model inference.');
}catch(error){console.error(error);await capture('phone-failure');process.exitCode=1;}
finally{writeFileSync('qa/phone-errors.json',JSON.stringify(errors,null,2));await browser.close();}
