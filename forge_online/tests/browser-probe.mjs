import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
import {mkdirSync,writeFileSync} from 'node:fs';
mkdirSync('qa',{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage();
const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('http://127.0.0.1:5173/signin-with-chatgpt?return_to=/',{waitUntil:'networkidle'});
await page.waitForSelector('flutter-view',{timeout:90000});
const accessibility=page.locator('flt-semantics-placeholder');
if(await accessibility.count())await accessibility.evaluate(el=>el.click());
await page.waitForTimeout(1500);
await page.screenshot({path:'qa/onboarding-browser.png',fullPage:true});
writeFileSync('qa/onboarding-aria.txt',await page.locator('body').ariaSnapshot());
console.log(JSON.stringify({url:page.url(),errors,aria:(await page.locator('body').ariaSnapshot()).slice(0,7000)}));
await browser.close();

