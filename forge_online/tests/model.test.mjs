import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import ort from 'onnxruntime-web';
test('deployed Food101 model has trained, non-degenerate logits and matches its checksum',async()=>{
 const model=readFileSync('public/vision/food101.onnx'),info=JSON.parse(readFileSync('public/vision/model-info.json'));
 assert.equal(createHash('sha256').update(model).digest('hex'),info.model_sha256);
 ort.env.wasm.numThreads=1;ort.env.wasm.wasmPaths=pathToFileURL(path.resolve('node_modules/onnxruntime-web/dist')+path.sep).href;
 const session=await ort.InferenceSession.create(model,{executionProviders:['wasm']}),tensor=new ort.Tensor('float32',new Float32Array(3*224*224),[1,3,224,224]);
 try{const out=await session.run({[session.inputNames[0]]:tensor}),values=Array.from(out[session.outputNames[0]].data);assert.equal(values.length,101);assert(values.every(Number.isFinite));assert(Math.max(...values)-Math.min(...values)>1);assert(Math.abs(Math.max(...values)-info.zero_input_logit_range[1])<.01);for(const value of Object.values(out))value.dispose();}finally{tensor.dispose();await session.release();}
});
