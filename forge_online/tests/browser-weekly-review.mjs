// Real app/service; synthetic users and in-memory data only.
import {createRequire} from 'node:module';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {makeService} from '../lib/service.mjs';
const require=createRequire(import.meta.url),{chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const db=new DatabaseSync(':memory:');
for(const name of readdirSync('drizzle').filter(n=>n.endsWith('.sql')).sort())db.exec(readFileSync('drizzle/'+name,'utf8').replaceAll('--> statement-breakpoint',''));
const bind=(sql,args)=>({first:async()=>db.prepare(sql).get(...args)??null,all:async()=>({results:db.prepare(sql).all(...args)}),run:async()=>db.prepare(sql).run(...args)});
const DB={prepare:sql=>({...bind(sql,[]),bind:(...args)=>bind(sql,args)}),batch:async ss=>{db.exec('BEGIN');try{const result=[];for(const s of ss)result.push(await s.run());db.exec('COMMIT');return result;}catch(e){db.exec('ROLLBACK');throw e;}}};
function record(key,value){db.prepare('INSERT INTO user_records VALUES(?,?,?,?,?,?)').run('weekly-fixture',key,JSON.stringify(value),'1792000000000001-fixture',0,'2026-10-19T00:00:00Z');}
const targets={trainingDays:5,calories:2000,protein:120,waterMl:2000,recovery:false};
record('profile',{name:'Weekly Test',sex:'Male',goal:'Build muscle',weight:75,height:175,age:25,activity:1.55,equipment:'Full gym',experience:'Beginner',days:5,trainingDays:[1,2,3,4,5]});
record('preferences',{waterTargetMl:2000,weeklyXpStart:'2026-10-19',weeklyXpOffsetMinutes:300});
record('weekplan:2026-10-19',targets);record('weekplan:2026-10-26',targets);
for(let i=19;i<=25;i++){
 const date='2026-10-'+i;
 record('meal:fixture-'+i,{id:'fixture-'+i,date,name:'Synthetic daily meals',type:'Dinner',calories:2000,protein:i===21?100:120,carbs:200,fat:70,notes:'Test data only',estimated:false,source:'Fixture'});
 record('water:'+date,8);
 if(i>=20&&i<=24)record('session:'+date,{name:'Test completed workout',done:true,sets:{}});
}
record('session:2026-10-18',{name:'Prior history',done:true,sets:{}});
record('meal:today',{id:'today',date:'2026-10-29',name:'Synthetic lunch',type:'Lunch',calories:600,protein:30,carbs:70,fat:20,notes:'Test only',estimated:false,source:'Fixture'});
record('water:2026-10-29',4);
db.exec('INSERT INTO catalog_state VALUES(1,39,1)');
const service=makeService(JSON.parse(readFileSync('data/catalog-basic.json')),JSON.parse(readFileSync('data/catalog-info.json')));
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']}),context=await browser.newContext({viewport:{width:360,height:800},isMobile:true,hasTouch:true,timezoneId:'Asia/Karachi'}),page=await context.newPage(),errors=[],checks=[];
page.setDefaultTimeout(20000);page.on('pageerror',e=>errors.push(e.message));
await context.route('**/api/**',async route=>{const r=route.request(),response=await service(new Request(r.url(),{method:r.method(),headers:{...r.headers(),origin:'http://127.0.0.1:5173'},body:['POST','DELETE'].includes(r.method())?r.postData():undefined}),{DB},{userId:'weekly-fixture'});await route.fulfill({status:response.status,body:await response.text(),headers:{'Content-Type':'application/json'}});});
async function enable(){await page.waitForSelector('flutter-view',{timeout:90000});const el=page.locator('flt-semantics-placeholder');if(await el.count())await el.evaluate(e=>e.click());await page.waitForTimeout(500);}
async function scroll(el){for(let i=0;i<28;i++){const b=await el.boundingBox();if(b&&b.y+b.height/2>=64&&b.y+b.height/2<=750)return;await page.mouse.move(260,450);await page.mouse.wheel(0,b?Math.max(-500,Math.min(500,b.y-350)):400);await page.waitForTimeout(150);}throw new Error('Could not scroll to target');}
async function open(){const button=page.getByRole('button',{name:'Daily check-in & weekly XP',exact:true});await scroll(button);await button.click();await page.waitForTimeout(300);}
try{
 await page.goto('http://127.0.0.1:5173/fitness/');await enable();assert.match(await page.locator('body').ariaSnapshot(),/515 XP/);await open();
 let snapshot=await page.locator('body').ariaSnapshot();assert.match(snapshot,/1 meal logged/);assert.match(snapshot,/30.0 \/ 120 g/);assert.match(snapshot,/1000 \/ 2000 ml/);assert.match(snapshot,/About 90 g protein remains/);checks.push('360px phone shows meal count, personal macro/water progress and specific next steps');
 await scroll(page.getByRole('button',{name:/^Monday no completed workout/}));await page.screenshot({path:'qa/weekly-checkin-phone.png'});snapshot=await page.locator('body').ariaSnapshot();assert.match(snapshot,/no XP deducted yet/);
 const prev=page.getByRole('button',{name:/^Previous check-in day/});for(let i=0;i<8;i++){await scroll(prev);await prev.click();await page.mouse.move(350,450);await page.waitForTimeout(150);}
 snapshot=await page.locator('body').ariaSnapshot();assert.match(snapshot,/5 \/ 5 workouts completed/);assert.match(snapshot,/Week closed · −5 XP applied/);assert.match(snapshot,/100.0 \/ 120 g/);assert.match(snapshot,/Protein gaps: 1 days × 5 XP/);await scroll(page.getByRole('button',{name:/^Monday no completed workout/}));await page.screenshot({path:'qa/weekly-closed-phone.png'});checks.push('Closed week counts Saturday make-up, explains one protein gap and applies exactly 5 XP once');
 await page.getByRole('button',{name:'Back',exact:true}).click();await open();const recovery=page.getByRole('checkbox',{name:/^Recovery week/});await scroll(recovery);await recovery.click();await page.waitForTimeout(1400);assert.equal(JSON.parse(db.prepare("SELECT value_json FROM user_records WHERE record_key='weekplan:2026-10-26'").get().value_json).recovery,true);
 await page.reload();await enable();assert.match(await page.locator('body').ariaSnapshot(),/515 XP/);await open();await scroll(page.getByRole('button',{name:/^Monday no completed workout/}));assert.match(await page.locator('body').ariaSnapshot(),/Recovery week: weekly deductions are paused/);checks.push('Recovery choice syncs and survives reload; completed week deduction is unchanged');
 await page.setViewportSize({width:1440,height:1000});await page.waitForTimeout(500);await page.screenshot({path:'qa/weekly-checkin-desktop.png'});assert.equal(errors.length,0);
 writeFileSync('qa/weekly-browser-verification.json',JSON.stringify({checks,errors,engine:'Isolated Edge, real app/service with synthetic account and Pakistan timezone',completedAt:new Date().toISOString()},null,2));console.log('PASS '+JSON.stringify(checks));
}catch(e){console.error(e);await page.screenshot({path:'qa/weekly-failure.png'});writeFileSync('qa/weekly-failure.txt',await page.locator('body').ariaSnapshot());process.exitCode=1;}finally{await browser.close();}
