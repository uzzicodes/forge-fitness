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
record('session:'+date,{name:'Push test',done:false,exerciseIds:['bench','row'],plannedSets:2,rotationIndex:0,rotationSize:5,sets:{'bench-0':{reps:8,kg:50,checked:true},'row-0':{reps:10,kg:20,checked:true},'row-1':{reps:10,kg:20,checked:true}}});
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
 await page.goto(base+'/fitness/');await enable();await tab('Train');await page.getByRole('button',{name:'I’m training',exact:true}).click();
 const swap=page.getByRole('button',{name:'Swap / move Barbell bench press',exact:true});await scrollTo(swap);await swap.click();
 await page.getByRole('button',{name:/^Machine chest press Full gym/}).click();await page.waitForTimeout(1100);
 let saved=records.get('session:'+date).value;assert.deepEqual(saved.exerciseIds,['machinechest','row']);assert.equal(saved.setTargets.machinechest,1);assert.equal(saved.sets['bench-0'].kg,50);assert.equal(saved.done,false);assert.equal(saved.sets['machinechest-0'],undefined);checks.push('Partial exercise swap syncs a matching replacement, preserves saved 50 kg set and requires only one remaining set');
 await page.screenshot({path:'qa/swap-phone.png'});
 const move=page.getByRole('button',{name:'Swap / move Machine chest press',exact:true});await scrollTo(move);await move.click();await page.getByRole('button',{name:'Move this exercise to the end',exact:true}).click();await page.waitForTimeout(1100);
 saved=records.get('session:'+date).value;assert.deepEqual(saved.exerciseIds,['row','machinechest']);checks.push('Busy exercise can be moved to the end without changing completed sets');
 const check=page.getByRole('button',{name:'Save completed set',exact:true});await scrollTo(check);await check.click();await page.waitForTimeout(400);
 const skip=page.getByRole('button',{name:/Skip/});if(await skip.count())await skip.click();
 const finish=page.getByRole('button',{name:'Finish workout',exact:true});await scrollTo(finish);await finish.click();await page.getByText('+60 XP',{exact:true}).waitFor();await page.getByRole('button',{name:'Keep going',exact:true}).click();await page.waitForTimeout(1100);
 saved=records.get('session:'+date).value;assert.equal(saved.done,true);assert.equal(saved.sets['machinechest-0'].kg,0);assert.equal(saved.sets['machinechest-0'].checked,true);assert.equal(saved.sets['bench-0'].checked,true);checks.push('Replacement starts with its own load, finishes the original set budget and awards normal completion XP');
 await page.reload();await enable();assert.match(await page.locator('body').ariaSnapshot(),/120 XP/);await tab('Train');await page.getByRole('button',{name:'View completed workout →',exact:true}).click();assert.match(await page.locator('body').ariaSnapshot(),/Machine chest press/);checks.push('Completed swapped workout and rank survive a fresh synchronized reload');
 assert.equal(errors.length,0);writeFileSync('qa/swap-browser-verification.json',JSON.stringify({engine:'Isolated Edge phone, synthetic API only; no personal data touched',checks,errors,completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}catch(e){console.error(e);await page.screenshot({path:'qa/swap-failure.png'});writeFileSync('qa/swap-failure.txt',await page.locator('body').ariaSnapshot());process.exitCode=1;}
finally{await browser.close();}
