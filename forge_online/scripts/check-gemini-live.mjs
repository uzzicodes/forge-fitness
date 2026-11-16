// Build-time integration check. The key is accepted on hidden stdin, never stored.
import {readFileSync,writeFileSync} from 'node:fs';
import {geminiEstimate} from '../lib/service.mjs';
async function privateInput(){
 if(!process.stdin.isTTY)throw new Error('Use a private TTY for key input.');
 process.stdin.setRawMode(true);process.stdin.resume();
 process.stdout.write('Ready for private Gemini check input (hidden)\n');
 return new Promise(resolve=>{let value='';const onData=chunk=>{value+=chunk.toString();if(/[\r\n]/.test(value)){process.stdin.removeListener('data',onData);process.stdin.setRawMode(false);process.stdin.pause();process.stdin.unref?.();resolve(value.trim());}};process.stdin.on('data',onData);});
}
const key=await privateInput();
try{
 const image='data:image/jpeg;base64,'+readFileSync('downloads/food101-validation.jpg').toString('base64');
 const result=await geminiEstimate({description:'Estimate only the beignets on the foreground plate, not the drinks. Assume I ate three medium pieces.',context:'Use explicit typical serving assumptions. This is a public validation photo.',image},key,async(url,options)=>{const response=await fetch(url,options);if(!response.ok){const error=await response.clone().json().catch(()=>({}));console.log(JSON.stringify({googleStatus:response.status,googleError:error.error?.status,reason:error.error?.details?.map(d=>d.reason).filter(Boolean)}));}return response;});
 const proof={checkedAt:new Date().toISOString(),model:'gemini-3.5-flash-lite',fixture:'Public ETHZ Food101 validation sample, not a user photo',ok:true,result};
 writeFileSync('qa/gemini-live-check.json',JSON.stringify(proof,null,2));
 console.log(JSON.stringify({ok:true,isFood:result.is_food,needsClarification:result.needsClarification,name:result.name,calories:result.calories,protein:result.protein}));
}catch(error){console.log(JSON.stringify({ok:false,status:error.status||null,message:error.message}));process.exitCode=1;}
