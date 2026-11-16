// Isolated synthetic responses: this test never reads or writes a user's API data.
import {createRequire} from 'node:module';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173';
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,timezoneId:'Asia/Karachi'});
const page=await context.newPage(),errors=[],changes=[],failedRequests=[];page.setDefaultTimeout(20000);page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>failedRequests.push(r.url()));
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
async function type(name,value){const field=page.getByRole('textbox',{name,exact:true});await scrollTo(field);await field.click();await page.waitForTimeout(100);await page.keyboard.press('Control+A');await page.keyboard.type(value,{delay:20});await page.keyboard.press('Tab');await page.waitForTimeout(200);}
const checks=[];
try{
 await page.goto(base+'/fitness/');await enable();
 const entry=page.getByRole('button',{name:'Food ideas & prices',exact:true});await scrollTo(entry);await entry.click();await page.getByRole('textbox',{name:'Search foods or meals',exact:true}).waitFor();await page.screenshot({path:'qa/guide-phone.png'});checks.push('Dedicated food-guide page opens from Daily Fuel');
 await type('Search foods or meals','Boiled eggs');const eggPhoto=page.getByRole('img',{name:'Example photo: Boiled eggs',exact:true});await scrollTo(eggPhoto);await page.screenshot({path:'qa/guide-eggs-photo.png'});checks.push('Food card includes an accessible food photograph on a phone viewport');const review=page.getByRole('button',{name:'Review & log',exact:true});await scrollTo(review);await review.click();assert.equal([...records.values()].filter(r=>r.key.startsWith('meal:')).length,0);
 await page.getByRole('button',{name:'Cancel',exact:true}).click();await page.waitForTimeout(350);assert.equal([...records.values()].filter(r=>r.key.startsWith('meal:')).length,0);checks.push('Browsing and cancelling the serving review never log a meal');
 await scrollTo(review);await review.click();await page.getByRole('button',{name:'Yes, log this serving',exact:true}).click();await page.waitForTimeout(1200);
 let meals=[...records.values()].filter(r=>r.key.startsWith('meal:'));assert.equal(meals.length,1);assert.equal(meals[0].value.calories,155);assert.equal(meals[0].value.protein,12.6);checks.push('Explicit confirmation logs the stated two-egg portion and syncs its macros');
 await page.evaluate(async()=>{await navigator.serviceWorker.ready;});await page.waitForFunction(()=>!!navigator.serviceWorker.controller);
 const cachedPhotos=await page.evaluate(async()=>{const cache=await caches.open((await caches.keys()).find(k=>k.startsWith('forge-')));const keys=await cache.keys();return keys.filter(r=>r.url.includes('/food-images/')).length;});assert.equal(cachedPhotos,14);checks.push('All 14 bundled food photographs are saved in the offline app cache');
 offline=true;await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded'});await enable();await scrollTo(entry);await entry.click();await page.getByRole('textbox',{name:'Search foods or meals',exact:true}).waitFor();await type('Search foods or meals','rice');assert.match(await page.locator('body').ariaSnapshot(),/No matches/);
 // Rice is an energy source, so switch out of the protein-only category.
 const boosters=page.getByRole('checkbox',{name:'Calorie boosters',exact:true});await scrollTo(boosters);await boosters.click();await page.waitForTimeout(200);assert.match(await page.locator('body').ariaSnapshot(),/Plain cooked rice/);checks.push('Cached guide and local filtering work offline; protein/energy categories stay distinct');
 await type('Search foods or meals','');const ideas=page.getByRole('checkbox',{name:'Meal ideas',exact:true});await scrollTo(ideas);await ideas.click();await type('Search foods or meals','Banana, oats');await scrollTo(page.getByRole('img',{name:'Example photo: Whole milk',exact:true}));assert.equal(await page.getByRole('img',{name:/Example photo:/}).count(),4);await page.waitForTimeout(900);await page.screenshot({path:'qa/guide-shake-photos-offline.png'});checks.push('Four ingredient photographs render for the shake while offline');
 await page.setViewportSize({width:1440,height:1000});await page.waitForTimeout(400);await page.screenshot({path:'qa/guide-desktop.png'});assert.equal(errors.length,0);
 assert(await page.evaluate(async()=>!!(await caches.match('/fitness/assets/assets/fonts/Roboto-Regular.ttf'))&&!!(await caches.match('/fitness/assets/assets/fonts/Roboto-Medium.ttf'))),'Primary text fonts must be cached locally');checks.push('Both primary text fonts are bundled in the offline cache; labels verified in the offline screenshot');
 writeFileSync('qa/food-guide-browser-verification.json',JSON.stringify({engine:'Isolated Edge phone and desktop; synthetic personal APIs, real bundled guide data',checks,errors,failedRequests:[...new Set(failedRequests)],completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}catch(e){console.error(e);await page.screenshot({path:'qa/guide-failure.png'});writeFileSync('qa/guide-failure.txt',await page.locator('body').ariaSnapshot());process.exitCode=1;}
finally{await browser.close();}
