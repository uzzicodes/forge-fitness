// Isolated synthetic responses: this test never reads or writes a user's API data.
import {createRequire} from 'node:module';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173';
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,timezoneId:'Asia/Karachi'});
const page=await context.newPage(),errors=[],changes=[];page.setDefaultTimeout(20000);page.on('pageerror',e=>errors.push(e.message));
const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Karachi'}).format(new Date());
const prior=new Date(date+'T12:00:00Z');prior.setUTCDate(prior.getUTCDate()-1);
const records=new Map();let offline=false;
function record(key,value){records.set(key,{key,value,clock:'1793090000000001-test-fixture'});}
record('profile',{name:'Rank Tester',sex:'Male',goal:'Lean & defined',equipment:'Full gym',experience:'Beginner',weight:75,height:178,age:25,activity:1.375,days:5,trainingDays:[1,2,3,4,5]});
record('session:'+prior.toISOString().slice(0,10),{name:'Prior workout',done:true,sets:{}});
record('attendance:'+date,'train');
record('session:'+date,{name:'Push test',done:false,exerciseIds:['bench'],plannedSets:1,rotationIndex:0,rotationSize:5,sets:{'bench-0':{reps:10,kg:20,checked:true}}});
await context.route('**/api/**',async route=>{
 if(offline)return route.abort('internetdisconnected');
 const path=new URL(route.request().url()).pathname;
 if(path==='/api/local-pair')return route.fulfill({json:{token:'synthetic-test-token',hosted:true}});
 if(path==='/api/status')return route.fulfill({json:{ok:true,hosted:true,userId:'synthetic-browser-fixture',catalogReady:true,configured:false}});
 if(path==='/api/state')return route.fulfill({json:{records:[...records.values()]}});
 if(path==='/api/sync'){
  const body=route.request().postDataJSON();changes.push(...body.changes);for(const op of body.changes)records.set(op.key,op);
  return route.fulfill({json:{ok:true,accepted:body.changes.map(c=>({key:c.key,clock:c.clock}))}});
 }
 return route.fulfill({status:404,json:{error:'Synthetic test route unavailable'}});
});
async function enable(){await page.waitForSelector('flutter-view',{timeout:90000});const el=page.locator('flt-semantics-placeholder');if(await el.count())await el.evaluate(e=>e.click());await page.waitForTimeout(500);}
async function tab(name){await page.getByRole('tab',{name,exact:true}).click();await page.waitForTimeout(300);}
async function scrollTo(locator){for(let i=0;i<12&&!await locator.isVisible();i++){await page.mouse.move(280,470);await page.mouse.wheel(0,480);await page.waitForTimeout(150);}await locator.scrollIntoViewIfNeeded();}
const checks=[];
try{
 await page.goto(base+'/fitness/index.html');await enable();
 const header=page.getByRole('button',{name:/View your rank and rank ladder/}).first();await header.waitFor();
 assert((await header.boundingBox()).y<160);await page.screenshot({path:'qa/rank-header-phone.png'});
 await header.click();await page.getByRole('button',{name:'Back to FORGE',exact:true}).click();checks.push('Current rank emblem is above the greeting and opens the ladder');
 await tab('Habits');assert.match(await page.locator('body').ariaSnapshot(),/Iron I/);assert.match(await page.locator('body').ariaSnapshot(),/60 rank XP/);
 await page.screenshot({path:'qa/rank-phone.png'});checks.push('Phone rank badge and existing workout XP render');
 await page.getByRole('button',{name:'View all ranks',exact:true}).click();
 for(let i=0;i<10&&!await page.getByRole('img',{name:/^Radiant rank badge/}).count();i++){await page.mouse.move(280,530);await page.mouse.wheel(0,550);await page.waitForTimeout(180);}
 assert.equal(await page.getByRole('img',{name:/^Radiant rank badge/}).count(),1);await page.screenshot({path:'qa/rank-ladder.png'});
 await page.getByRole('button',{name:'Back to FORGE',exact:true}).click();checks.push('Scrollable rank ladder reaches Radiant');
 await tab('Train');
 await page.getByRole('button',{name:'I’m training',exact:true}).click();
 const finish=page.getByRole('button',{name:'Finish workout',exact:true});await scrollTo(finish);await finish.click();
 await page.getByText('RANK UP!',{exact:true}).waitFor();assert.equal(await page.getByText('+60 XP',{exact:true}).count(),1);assert.equal(await page.getByText('Iron II',{exact:true}).count(),1);
 await page.waitForTimeout(350);await page.screenshot({path:'qa/rank-promotion.png'});await page.getByRole('button',{name:'Keep going',exact:true}).click();await page.waitForTimeout(1000);
 assert.equal(records.get('session:'+date).value.done,true);checks.push('Real finish action syncs completion and shows +60 XP and Iron II promotion');
 await page.getByRole('button',{name:'Reopen workout',exact:true}).click();await page.waitForTimeout(1000);assert.equal(records.get('session:'+date).value.done,false);
 await page.getByRole('button',{name:'Finish workout',exact:true}).click();await page.getByText('+60 XP',{exact:true}).waitFor();await page.getByRole('button',{name:'Keep going',exact:true}).click();await page.waitForTimeout(1000);
 await page.getByRole('button',{name:'Back',exact:true}).click();await tab('Habits');assert.match(await page.locator('body').ariaSnapshot(),/120 rank XP/);checks.push('Reopening and finishing restores 120 total XP without duplicate points');
 await page.reload();await enable();await tab('Habits');assert.match(await page.locator('body').ariaSnapshot(),/Iron II/);assert.match(await page.locator('body').ariaSnapshot(),/120 rank XP/);checks.push('Rank survives a fresh reload from synchronized records');
 await page.evaluate(async()=>{await navigator.serviceWorker.ready;});await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
 offline=true;await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded'});await enable();await tab('Habits');assert.match(await page.locator('body').ariaSnapshot(),/120 rank XP/);checks.push('Cached app and rank remain usable after an offline reload');
 offline=false;await context.setOffline(false);
 await page.setViewportSize({width:1440,height:1000});await page.waitForTimeout(400);await page.screenshot({path:'qa/rank-desktop.png'});assert.equal(errors.length,0);
 writeFileSync('qa/rank-browser-verification.json',JSON.stringify({engine:'Isolated Edge, phone and desktop; synthetic API only, no personal data touched',checks,errors,completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}catch(e){console.error(e);await page.screenshot({path:'qa/rank-failure.png'});writeFileSync('qa/rank-failure.txt',await page.locator('body').ariaSnapshot());process.exitCode=1;}
finally{await browser.close();}
