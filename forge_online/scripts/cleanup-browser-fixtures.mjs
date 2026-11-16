// Revert only this test browser's changes. Existing/user-edited records are preserved.
import {createRequire} from 'node:module';
import {readFileSync,statSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173',report=JSON.parse(readFileSync('qa/v2-browser-verification.json')),fixture=JSON.parse(readFileSync('qa/gemini-live-check.json')).result;
const start=statSync('qa/v2-meal-review.png').mtimeMs-3000,end=Date.parse(report.completedAt)+3000;
const browser=await chromium.launch({channel:'msedge',headless:true}),context=await browser.newContext(),page=await context.newPage();
try{
 await page.goto(base+'/signin-with-chatgpt?return_to=/',{waitUntil:'networkidle'});
 const data=await(await context.request.get(base+'/api/state')).json();
 const within=r=>Number(r.clock.slice(0,16))/1000>=start&&Number(r.clock.slice(0,16))/1000<=end;
 const photo=data.records.find(r=>r.key.startsWith('meal:')&&r.value?.name===fixture.name&&r.value?.source==='Gemini estimate'&&within(r));
 if(!photo){console.log(JSON.stringify({planned:0,reason:'The uniquely identified photo test record is absent or has been edited; no records changed.'}));process.exitCode=0;}
 else{
  const actor=photo.clock.slice(17),owned=r=>within(r)&&r.clock.slice(17)===actor;
  const meals=data.records.filter(r=>r.key.startsWith('meal:')&&owned(r)&&(r.value?.name===fixture.name||(r.value?.name==='Boiled eggs'&&r.value?.notes.startsWith('I ate 3 boiled eggs\n'))));assert(meals.length>=1&&meals.length<=2);
  const changes=meals.map(r=>({key:r.key,value:null,ifClock:r.clock}));
  const water=data.records.find(r=>r.key==='water:2026-10-27');if(water&&owned(water)&&water.value>=3)changes.push({key:water.key,value:water.value-3,ifClock:water.clock});
  const log=data.records.find(r=>r.key==='habitlog:2026-10-27');if(log&&owned(log)&&log.value?.walk===true)changes.push({key:log.key,value:{...log.value,walk:false},ifClock:log.clock});
  const habit=data.records.find(r=>r.key==='habit:walk');if(habit&&owned(habit)&&habit.value?.title==='Take a short walk')changes.push({key:habit.key,value:{...habit.value,enabled:false},ifClock:habit.clock});
  const summary={mealFixtures:meals.length,waterDeltaMl:changes.some(c=>c.key.startsWith('water:'))?750:0,habitChanges:changes.filter(c=>c.key.startsWith('habit')).length,ownershipProof:'Same isolated browser client and test time window as unique public-photo fixture',clientFingerprint:createHash('sha256').update(actor).digest('hex').slice(0,12),preservesConcurrentEdits:true,goalKept:'Lean & defined'};
  if(process.argv.includes('--apply')){
   const now=Date.now()*1000;for(let i=0;i<changes.length;i++)changes[i].clock=String(now+i)+'-qa-fixture-cleanup';
   const r=await context.request.post(base+'/api/sync',{headers:{Origin:base},data:{changes}});assert.equal(r.status(),200);
   writeFileSync('qa/v2-fixture-cleanup.json',JSON.stringify({...summary,applied:true},null,2));
  }
  console.log(JSON.stringify({...summary,applied:process.argv.includes('--apply')}));
 }
}finally{await browser.close();}
