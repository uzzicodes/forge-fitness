import {cpSync,mkdirSync,readdirSync,readFileSync,writeFileSync,statSync} from 'node:fs';
import {resolve,relative,basename,sep} from 'node:path';
import {createHash} from 'node:crypto';
import {serviceWorkerSource} from './service-worker.mjs';
const source=resolve('../forge_fitness'),target=resolve('public/fitness');
mkdirSync(target,{recursive:true});
cpSync(resolve(source,'build/web'),target,{recursive:true,filter:path=>!basename(path).startsWith('skwasm')&&!path.endsWith('.map')&&!basename(path).startsWith('.')});
let html=readFileSync(resolve(target,'index.html'),'utf8');
html=html.replace('</head>','<script src="/vision/vision.js" defer></script>\n<script src="/vision/barcode.min.js" defer></script>\n</head>');
writeFileSync(resolve(target,'index.html'),html);
const manifest=JSON.parse(readFileSync(resolve(target,'manifest.json'),'utf8').replace(/^\uFEFF/,''));
manifest.start_url='/fitness/';manifest.scope='/';writeFileSync(resolve(target,'manifest.json'),JSON.stringify(manifest,null,2));
function walk(dir){return readdirSync(dir).flatMap(name=>{const path=resolve(dir,name);return statSync(path).isDirectory()?walk(path):[path];});}
const files=walk(target).filter(file=>!/(forge-sw|flutter_service_worker)\.js$/.test(file));
const extra=['public/vision/vision.js','public/vision/labels.json','public/vision/barcode.min.js','public/vision/ZXING-LICENSE.txt','public/demos/manifest.json',...walk(resolve('public/demos')).filter(p=>p.endsWith('.jpg'))];
const hash=createHash('sha256');hash.update(readFileSync(new URL(import.meta.url)));hash.update(readFileSync(new URL('./service-worker.mjs',import.meta.url)));for(const file of [...files,...extra])hash.update(readFileSync(file));const version=hash.digest('hex').slice(0,16);
const urls=[...files,...extra.map(p=>resolve(p))].map(file=>'/'+relative(resolve('public'),file).split(sep).join('/'));
const sw=serviceWorkerSource(version,urls);
writeFileSync('public/forge-sw.js',sw);
mkdirSync('flutter-src',{recursive:true});
for(const dir of ['lib','web','test','assets'])cpSync(resolve(source,dir),resolve('flutter-src',dir),{recursive:true});
for(const file of ['pubspec.yaml','pubspec.lock','analysis_options.yaml'])cpSync(resolve(source,file),resolve('flutter-src',file));
console.log('Prepared online Flutter assets, reproducible Dart sources, and offline worker '+version);

