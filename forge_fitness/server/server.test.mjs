import test from 'node:test';
import assert from 'node:assert/strict';
import {createForgeServer,validateImage,validateEstimate,analyzeWithOpenAI} from './server.mjs';
const token='local-test-token-for-forge';
const photo='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jK1sAAAAASUVORK5CYII=';
const meal=()=>({is_food:true,name:'Chicken rice',portion:'150 g chicken, 1 cup rice',calories:650,protein:45,carbs:70,fat:20,assumptions:'Portion and cooking oil estimated.'});
async function fixture(t,options={}){const server=createForgeServer({token,...options});await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));return 'http://127.0.0.1:'+server.address().port;}
test('unauthorized API calls cannot use the AI account',async t=>{const base=await fixture(t);const r=await fetch(base+'/api/status');assert.equal(r.status,401);});
test('status reports missing API key and photo calls explain setup',async t=>{const base=await fixture(t);const headers={Authorization:'Bearer '+token};assert.equal((await (await fetch(base+'/api/status',{headers})).json()).configured,false);const r=await fetch(base+'/api/analyze',{method:'POST',headers});assert.equal(r.status,503);assert.match((await r.json()).error,/OPENAI_API_KEY/);});
test('analysis validates image and returns estimated macros',async t=>{let count=0;const base=await fixture(t,{key:'test',analyzer:async(image,notes)=>{count++;assert.equal(image,photo);assert.equal(notes,'one bowl');return meal();}});const headers={Authorization:'Bearer '+token,'Content-Type':'application/json'};const r=await fetch(base+'/api/analyze',{method:'POST',headers,body:JSON.stringify({image:photo,context:'one bowl'})});assert.equal(r.status,200);assert.equal((await r.json()).protein,45);const bad=await fetch(base+'/api/analyze',{method:'POST',headers,body:JSON.stringify({image:'not a photo'})});assert.equal(bad.status,400);assert.equal(count,1);});
test('rejects external browser origins',async t=>{const base=await fixture(t);const r=await fetch(base+'/api/status',{headers:{Authorization:'Bearer '+token,Origin:'https://untrusted.example'}});assert.equal(r.status,403);});
test('nonfood and invalid estimates are rejected',()=>{assert.throws(()=>validateImage('data:image/png;base64,YWJjZA=='));assert.throws(()=>validateEstimate({...meal(),is_food:false}),/No meal/);assert.throws(()=>validateEstimate({...meal(),calories:-1}),/Unusable/);});
test('OpenAI request uses schema, image input and no storage',async()=>{const result=await analyzeWithOpenAI(photo,'one bowl',{key:'never-log-this',model:'gpt-4.1-mini'},async(url,request)=>{const body=JSON.parse(request.body);assert.equal(url,'https://api.openai.com/v1/responses');assert.equal(body.store,false);assert.equal(body.text.format.strict,true);assert.equal(body.input[0].content[1].image_url,photo);return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(meal())}]}]})};});assert.equal(result.calories,650);});
test('upstream authentication errors are safe and actionable',async()=>{await assert.rejects(analyzeWithOpenAI(photo,'',{key:'secret',model:'gpt-4.1-mini'},async()=>({ok:false,status:401})),/API key was rejected/);});


test('a food name can be estimated without a photo',async t=>{
  const base=await fixture(t,{key:'test',analyzer:async(image,notes,options)=>{
    assert.equal(image,null);assert.equal(options.description,'banana shake');assert.equal(notes,'250 ml whole milk, one banana, no sugar');
    return {...meal(),name:'Banana shake',portion:'1 banana + 250 ml whole milk',assumptions:'No added sugar; estimated serving.'};
  }});
  const r=await fetch(base+'/api/analyze',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({description:'banana shake',context:'250 ml whole milk, one banana, no sugar'})});
  assert.equal(r.status,200);assert.match((await r.json()).portion,/250 ml/);
});
test('name-only model requests omit the image and state recipe assumptions',async()=>{
  await analyzeWithOpenAI(null,'one glass',{key:'test',model:'gpt-4.1-mini',description:'banana shake'},async(url,request)=>{
    const body=JSON.parse(request.body);assert.equal(body.input[0].content.length,1);assert.match(body.input[0].content[0].text,/banana shake/);assert.match(body.instructions,/milk type and volume/);
    return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(meal())}]}]})};
  });
});


test('desktop pairing is automatic only for a same-origin loopback request',async t=>{
 const base=await fixture(t);
 const good=await fetch(base+'/api/local-pair',{method:'POST',headers:{Origin:base}});
 assert.equal(good.status,200);assert.equal((await good.json()).token,token);
 const blocked=await fetch(base+'/api/local-pair',{method:'POST'});assert.equal(blocked.status,403);
 const rebind=await fetch(base+'/api/local-pair',{method:'POST',headers:{Origin:'http://localhost:1'}});assert.equal(rebind.status,403);
});
test('private setup page requires its anti-CSRF token to save a key',async t=>{
 const base=await fixture(t);
 const page=await fetch(base+'/configure');assert.equal(page.status,200);assert.match(await page.text(),/Verify & connect/);
 const post=await fetch(base+'/api/configure',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({key:'not-a-real-key',nonce:'wrong'})});assert.equal(post.status,403);
});


