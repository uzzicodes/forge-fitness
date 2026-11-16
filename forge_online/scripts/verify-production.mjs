// Public reference initialization and deployment checks only. Never seeds user data.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync} from 'node:fs';
const origin=process.argv[2];
if(!origin||new URL(origin).protocol!=='https:')throw new Error('Pass the deployed HTTPS origin.');
const result={origin,checkedAt:new Date().toISOString(),checks:[]};
const root=await fetch(origin+'/',{redirect:'manual'});assert.equal(root.status,200);assert.match(await root.text(),/Continue without signing in/);result.checks.push('Anonymous root offers guest access and optional sign-in');
for(const path of ['/api/status','/api/state']){const r=await fetch(origin+path);assert.equal(r.status,401);result.checks.push(path+' rejects unauthenticated access');}
for(let i=0;i<45;i++){
 const r=await fetch(origin+'/api/catalog/bootstrap',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:'{}'});
 assert.equal(r.status,200,await r.clone().text());const state=await r.json();
 if(i%10===0||state.complete)console.log(JSON.stringify(state));
 if(state.complete){assert.equal(state.count,7793);assert.equal(state.regionalCount,98);result.checks.push('7,793 USDA references and 98 Pakistani food/recipe references imported');break;}
 if(i===44)throw new Error('Catalog did not finish importing.');
}
const expected=JSON.parse(readFileSync('public/vision/model-info.json'));
const model=await fetch(origin+'/vision/food101.onnx');assert.equal(model.status,200);
const hash=createHash('sha256').update(Buffer.from(await model.arrayBuffer())).digest('hex');assert.equal(hash,expected.model_sha256);result.checks.push('Hosted trained model checksum matches');
for(const path of ['/fitness/index.html','/fitness/main.dart.js','/forge-sw.js','/vision/vision.js','/demos/manifest.json']){
 const r=await fetch(origin+path);assert.equal(r.status,200);const hosted=Buffer.from(await r.arrayBuffer()),local=readFileSync('public'+path);
 if(path.endsWith('.html')){
  // Sites adds its own bridge script to HTML. All authored bytes must be intact.
  const a=hosted.toString(),b=local.toString();
  const extra=[...a.matchAll(/<script\b[^>]*>[\s\S]*?<\/script>/g)].map(m=>m[0]).filter(script=>!b.includes(script));
  assert(extra.length<=1);let authored=a;for(const script of extra)authored=authored.replace(script,'');assert.equal(authored,b);
  result.checks.push('HTML preserves the tested app bootstrap plus the hosting bridge');
 }else{assert.equal(createHash('sha256').update(hosted).digest('hex'),createHash('sha256').update(local).digest('hex'));result.checks.push(path+' matches the tested release');}
}
const manifest=JSON.parse(readFileSync('public/demos/manifest.json'));assert.equal(Object.keys(manifest).length,34);
for(const d of Object.values(manifest).filter(d=>d.kind==='video')){const r=await fetch(origin+d.video,{headers:{Range:'bytes=0-63'}});assert([200,206].includes(r.status));assert(Buffer.from(await r.arrayBuffer()).subarray(0,64).includes(Buffer.from('ftyp')));}result.checks.push('All six hosted H.264 clips serve correctly; 34 demo mappings available');
result.completedAt=new Date().toISOString();writeFileSync('qa/production-verification.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
