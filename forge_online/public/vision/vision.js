let runtime,session;
async function load(){
 if(!runtime)runtime=new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='/vision/ort.min.js';script.onload=resolve;script.onerror=()=>reject(new Error('The photo matcher could not download. Use food search instead.'));document.head.appendChild(script);}).catch(error=>{runtime=null;throw error;});
 await runtime;
 if(!session){ort.env.wasm.numThreads=1;ort.env.wasm.proxy=false;ort.env.wasm.wasmPaths='/vision/';session=ort.InferenceSession.create('/vision/food101.onnx',{executionProviders:['wasm'],graphOptimizationLevel:'all'}).catch(error=>{session=null;throw error;});}
 return session;
}
window.forgeFoodSuggest=async function(dataUrl){
 const model=await load(),labels=await fetch('/vision/labels.json').then(r=>{if(!r.ok)throw new Error('Food labels are unavailable.');return r.json();});
 const picture=new Image();picture.src=dataUrl;await picture.decode();
 const scale=256/Math.min(picture.naturalWidth,picture.naturalHeight),crop=224/scale;
 const canvas=document.createElement('canvas');canvas.width=224;canvas.height=224;
 const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(picture,(picture.naturalWidth-crop)/2,(picture.naturalHeight-crop)/2,crop,crop,0,0,224,224);
 const pixels=ctx.getImageData(0,0,224,224).data,count=224*224,input=new Float32Array(3*count),mean=[.485,.456,.406],std=[.229,.224,.225];
 for(let p=0;p<count;p++)for(let c=0;c<3;c++)input[c*count+p]=(pixels[p*4+c]/255-mean[c])/std[c];
 const tensor=new ort.Tensor('float32',input,[1,3,224,224]);
 const output=await model.run({[model.inputNames[0]]:tensor}),logits=Array.from(output[model.outputNames[0]].data);
 const max=Math.max(...logits),exp=logits.map(x=>Math.exp(x-max)),sum=exp.reduce((a,b)=>a+b,0);
 const results=exp.map((p,i)=>({name:labels[i].replaceAll('_',' '),score:p/sum})).sort((a,b)=>b.score-a.score).slice(0,4);
 tensor.dispose?.();for(const value of Object.values(output))value.dispose?.();
 return JSON.stringify(results[0].score>=.12?results:[]);
};

