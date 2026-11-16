import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:5173';
mkdirSync('qa',{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage(),errors=[];
page.on('pageerror',e=>errors.push(e.message));
async function aria(name){const s=await page.locator('body').ariaSnapshot();writeFileSync('qa/'+name+'.txt',s);console.log('Captured '+name);}
async function enable(){await page.waitForSelector('flutter-view',{timeout:90000});const el=page.locator('flt-semantics-placeholder');if(await el.count())await el.evaluate(e=>e.click());await page.waitForTimeout(500);}
async function type(name,value){const box=page.getByRole('textbox',{name,exact:true});await box.click();await page.waitForTimeout(120);await page.keyboard.press('Control+A');await page.keyboard.type(value,{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(160);}
try{
 await page.goto(base+'/signin-with-chatgpt?return_to=/',{waitUntil:'networkidle'});await enable();
 if(await page.getByRole('textbox',{name:'What should we call you?',exact:true}).count()){
 await type('What should we call you?','Test Athlete');
 await type('Weight · kg','75');
 await type('Height · cm','178');
 await type('Age · 18+','25');
 assert.equal(await page.getByRole('checkbox',{checked:true}).count(),5);
 await page.getByRole('button',{name:'Build my plan',exact:true}).click();
 }
 await page.waitForTimeout(1500);await aria('dashboard-desktop');await page.screenshot({path:'qa/dashboard-desktop.png'});
 await page.getByRole('button',{name:'Log a meal',exact:true}).first().click();
 await aria('meal-editor');
 await type('What did you eat?','banana shake');
 await page.getByRole('button',{name:'Free food & portion calculator',exact:true}).click();
 await page.waitForTimeout(800);await aria('food-calculator');
 await page.getByRole('button',{name:'Use these nutrition values',exact:true}).click();
 await page.waitForTimeout(600);
 await page.screenshot({path:'qa/meal-calculated.png'});
 await page.getByRole('button',{name:'Confirm & add to my day',exact:true}).click();
 await page.waitForTimeout(1500);
 let state=await (await context.request.get(base+'/api/state')).json();
 assert(state.records.some(r=>r.key.startsWith('meal:')&&r.value?.calories===262.4));
 await page.getByRole('button',{name:'Rest today',exact:true}).click();await page.waitForTimeout(500);
 await aria('rest-check-in');
 await page.getByRole('button',{name:'I’m training',exact:true}).click();await page.waitForTimeout(500);
 await aria('workout');
 for(let i=0;i<14;i++){
  state=await (await context.request.get(base+'/api/state')).json();
  const session=state.records.find(r=>r.key.startsWith('session:')&&r.value?.name.includes('Push'))?.value;
  if(session&&Object.values(session.sets).filter(s=>s.checked).length===10)break;
  for(let scroll=0;!(await page.getByRole('button',{name:'Save completed set',exact:true}).count())&&scroll<8;scroll++){await page.mouse.move(900,500);await page.mouse.wheel(0,500);await page.waitForTimeout(200);}
  await page.getByRole('button',{name:'Save completed set',exact:true}).first().click();await page.waitForTimeout(180);
  if(await page.getByRole('button',{name:'Skip',exact:true}).count())await page.getByRole('button',{name:'Skip',exact:true}).click();
  await page.waitForTimeout(750);
 }
 await page.mouse.move(900,500);await page.mouse.wheel(0,1800);await page.waitForTimeout(250);
 await page.getByRole('button',{name:'Finish workout',exact:true}).click();await page.waitForTimeout(900);
 await aria('workout-complete');await page.screenshot({path:'qa/workout-complete.png'});
 await page.getByRole('button',{name:'Back',exact:true}).click();await page.waitForTimeout(900);
 state=await (await context.request.get(base+'/api/state')).json();
 assert(state.records.some(r=>r.key.startsWith('session:')&&r.value?.done===true));
 assert.equal(errors.length,0);
 console.log('PASS: onboarding, cloud hydration, banana shake, meal confirmation, rest/train check-in, ten saved sets and completed workout.');
}catch(e){console.error(e);await aria('flow-failure');process.exitCode=1;}
finally{writeFileSync('qa/browser-errors.json',JSON.stringify(errors,null,2));await browser.close();}
