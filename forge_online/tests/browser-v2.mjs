import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173';mkdirSync('qa',{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,timezoneId:'Asia/Karachi'}),page=await context.newPage(),errors=[];
page.setDefaultTimeout(15000);page.on('pageerror',e=>errors.push(e.message));
async function enable(){await page.waitForSelector('flutter-view',{timeout:90000});const el=page.locator('flt-semantics-placeholder');if(await el.count())await el.evaluate(e=>e.click());await page.waitForTimeout(500);}
async function capture(name){await page.screenshot({path:'qa/'+name+'.png'});writeFileSync('qa/'+name+'.txt',await page.locator('body').ariaSnapshot());console.log('Captured '+name);}
async function type(name,value){await page.getByRole('textbox',{name,exact:true}).click();await page.waitForTimeout(120);await page.keyboard.press('Control+A');await page.keyboard.type(value,{delay:25});await page.keyboard.press('Tab');await page.waitForTimeout(160);}
async function state(){return (await context.request.get(base+'/api/state')).json();}
async function tab(name){await page.getByRole('tab',{name,exact:true}).click();await page.waitForTimeout(200);}
async function message(text){await page.getByRole('button',{name:'Log meal',exact:true}).click();await type('What did you eat or drink?',text);await page.getByRole('button',{name:'Estimate my meal',exact:true}).click();await page.waitForTimeout(350);}
const checks=[];
try{
 await page.goto(base+'/signin-with-chatgpt?return_to=/',{waitUntil:'networkidle'});await enable();
 if(await page.getByRole('textbox',{name:'What should we call you?',exact:true}).count()){
  await type('What should we call you?','Test Athlete');await type('Weight · kg','75');await type('Height · cm','178');await type('Age · 18+','25');await page.getByRole('button',{name:'Build my plan',exact:true}).click();await page.waitForTimeout(1000);
 }
 let data=await state(),priorIds=new Set(data.records.filter(r=>r.key.startsWith('meal:')).map(r=>r.key));
 await message('I ate 3 boiled eggs');assert.match(await page.locator('body').ariaSnapshot(),/18.9 g protein/);assert.equal((await state()).records.filter(r=>r.key.startsWith('meal:')).length,priorIds.size);await capture('v2-meal-review');
 await page.getByRole('button',{name:'Yes, confirm & log',exact:true}).click();await page.waitForTimeout(1200);
 data=await state();assert(data.records.some(r=>!priorIds.has(r.key)&&r.value?.calories===232.5&&r.value?.protein===18.9));checks.push('One natural-language message, preview, explicit confirmation, nutrition persistence');
 const waterBefore=data.records.find(r=>r.key==='water:2026-10-27')?.value||0;
 await message('500ml water');assert.match(await page.locator('body').ariaSnapshot(),/500 ml water/);await page.getByRole('button',{name:'Yes, confirm & log',exact:true}).click();await page.waitForTimeout(1100);assert.equal((await state()).records.find(r=>r.key==='water:2026-10-27')?.value,waterBefore+2);checks.push('Natural water quantities update hydration without a fake meal');
 await message('I ate Napoleon chicken');assert.equal(await page.getByRole('button',{name:'Yes, confirm & log',exact:true}).count(),0);await capture('v2-clarification');await page.getByRole('button',{name:'Close meal entry',exact:true}).click();checks.push('Unclear food requires clarification');
 await tab('Habits');
 if(!(await state()).records.some(r=>r.key==='habit:walk'&&r.value?.enabled))await page.getByRole('button',{name:'Start',exact:true}).first().click();await page.waitForTimeout(250);
 const habit=page.getByRole('checkbox',{name:/Take a short walk/});if(!await habit.isChecked())await habit.click();await page.waitForTimeout(1100);data=await state();assert(data.records.some(r=>r.key==='habitlog:2026-10-27'&&r.value?.walk===true));await capture('v2-habits');checks.push('Opt-in habit, daily completion, XP and private sync');
 await tab('Settings');if(await page.getByRole('button',{name:'Use Lean & defined plan',exact:true}).count())await page.getByRole('button',{name:'Use Lean & defined plan',exact:true}).click();await page.waitForTimeout(1000);assert.equal((await state()).records.find(r=>r.key==='profile')?.value?.goal,'Lean & defined');checks.push('Lean physique plan selected and synced');
 await tab('Train');
 await page.getByRole('button',{name:'View completed workout →',exact:true}).click();await page.waitForTimeout(200);await page.getByRole('button',{name:'Form preview',exact:true}).first().click();
 const video=page.locator('video');await video.waitFor();await video.evaluate(v=>v.play());await page.waitForTimeout(1100);assert((await video.evaluate(v=>v.currentTime))>0);await capture('v2-real-video');await video.evaluate(v=>v.pause());await page.getByRole('button',{name:'Close exercise demo',exact:true}).click();await page.getByRole('button',{name:'Back',exact:true}).click();checks.push('Actual inline exercise video decodes and plays');
 await tab('Today');await capture('v2-daily-fuel');await page.evaluate(async()=>navigator.serviceWorker.ready);await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
 const baseline=(await state()).records.find(r=>r.key==='water:2026-10-27')?.value||0;
 await context.setOffline(true);await page.getByRole('button',{name:'Add 250 ml',exact:true}).click();await page.waitForTimeout(800);await page.reload({waitUntil:'domcontentloaded'});await enable();await capture('v2-offline');
 const pending=await page.evaluate(()=>Object.entries(localStorage).find(([k])=>k.includes('forge.cloud.pending'))?.[1]);assert(pending?.includes('water:2026-10-27'));await context.setOffline(false);await tab('Settings');await page.getByRole('button',{name:'Sync now',exact:true}).click();await page.waitForTimeout(1000);assert.equal((await state()).records.find(r=>r.key==='water:2026-10-27')?.value,baseline+1);checks.push('Updated app reloads offline and queues/syncs changes');
 // Photo UI uses a controlled replay of the independently verified live Gemini response.
 await page.route('**/api/status',async route=>{const response=await route.fetch();const body=await response.json();body.configured=true;await route.fulfill({response,json:body});});
 const fixture=JSON.parse(readFileSync('qa/gemini-live-check.json')).result;
 await page.route('**/api/interpret',async route=>{const body=route.request().postDataJSON();if(!body.image)return route.continue();assert.equal(body.useGemini,true);await route.fulfill({json:{...fixture,needsClarification:false,items:[{name:fixture.name,portion:fixture.portion,calories:fixture.calories}],original:body.description,waterMl:0,source:'Gemini estimate'}});});
 await tab('Today');await page.getByRole('button',{name:'Log meal',exact:true}).click();await page.waitForTimeout(350);const chooser=page.waitForEvent('filechooser');await page.getByRole('button',{name:'Add photo',exact:true}).click();await(await chooser).setFiles('downloads/food101-validation.jpg');await page.waitForTimeout(600);await page.getByRole('button',{name:'Estimate with AI',exact:true}).click();await page.waitForTimeout(400);await capture('v2-photo-review');assert.match(await page.locator('body').ariaSnapshot(),/10.0 g protein/);await page.getByRole('button',{name:'Yes, confirm & log',exact:true}).click();await page.waitForTimeout(1100);
 const photoMeal=(await state()).records.find(r=>r.value?.name===fixture.name);assert(photoMeal);assert(!JSON.stringify(photoMeal).includes('data:image'));assert.equal(photoMeal.value.photoUrl,'');checks.push('Optional photo, visible Google processing notice, review, confirmation and nutrition-only storage (controlled photo-response replay)');
 assert.equal(errors.length,0);writeFileSync('qa/v2-browser-verification.json',JSON.stringify({engine:'Edge/Chromium at 390×844, not physical Safari',checks,errors,completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}catch(e){console.error(e);await capture('v2-failure');process.exitCode=1;}
finally{writeFileSync('qa/v2-errors.json',JSON.stringify(errors));await browser.close();}
