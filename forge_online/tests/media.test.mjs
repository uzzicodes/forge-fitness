import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
const demos=JSON.parse(readFileSync('public/demos/manifest.json'));
test('each library exercise has an accurately mapped media source and attribution',()=>{
 const source=readFileSync('../forge_fitness/lib/training.dart','utf8');
 const ids=[...source.matchAll(/Exercise\(\s*['"]([^'"]+)['"]/g)].map(m=>m[1]);assert.equal(ids.length,34);assert.equal(Object.keys(demos).length,ids.length);
 for(const id of ids){const d=demos[id];assert(d,id);assert(d.title&&d.author&&d.license&&d.sourceUrl,id);if(d.kind==='video'){assert(existsSync('public'+d.video));assert(existsSync('public'+d.poster));assert.match(d.license,/CC BY-SA/);assert(readFileSync('public'+d.video).subarray(0,40).includes(Buffer.from('ftyp')));}else{assert.equal(d.kind,'youtube');assert.match(d.video,/^https:\/\/www.youtube-nocookie.com\/embed\/[\w-]+/);assert(d.watchUrl.startsWith('https://www.youtube.com/watch?v='));}}
});
