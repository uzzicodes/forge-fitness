import https from 'node:https';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const ca=readFileSync('server/certs/ca.pem'),token=readFileSync('server/.pairing-token','utf8').trim();
function request(path,method='GET',auth=false){return new Promise((resolve,reject)=>{const req=https.request('https://localhost:8788'+path,{ca,method,headers:auth?{Authorization:'Bearer '+token}:{}},res=>{let body='';res.on('data',chunk=>body+=chunk);res.on('end',()=>resolve({status:res.statusCode,body,type:res.headers['content-type']}));});req.on('error',reject);req.end();});}
const app=await request('/');assert.equal(app.status,200);assert.match(app.body,/FORGE/);
const setup=await request('/iphone');assert.equal(setup.status,200);assert.match(setup.body,/Add to Home Screen/);
const cert=await request('/forge-local-ca.cer','HEAD');assert.equal(cert.status,200);
const status=await request('/api/status','GET',true);assert.equal(status.status,200);assert.equal(JSON.parse(status.body).configured,false);
const unauthorized=await request('/api/status');assert.equal(unauthorized.status,401);
const sw=await request('/forge-sw.js');assert.equal(sw.status,200);assert.match(sw.body,/forge-offline-/);
const urls=JSON.parse(sw.body.match(/const FILES=(\[[^;]+\]);/)[1]);
for(const url of urls){const asset=await request(url,'HEAD');assert.equal(asset.status,200,url);}
const secret=await request('/server/.env');assert.equal(secret.status,404);
console.log('Local HTTPS verified with generated CA; setup page, API pairing, certificate download, secret exclusion and '+urls.length+' cached URLs passed. AI key is not configured.');

