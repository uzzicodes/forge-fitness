import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash} from 'node:crypto';
const g=JSON.parse(readFileSync('data/food-guide.json')),p=JSON.parse(readFileSync('data/food-guide-price-sources.json'));
test('food guide has bounded traceable prices and explicit prepared servings',()=>{
 assert.equal(g.foods.length,14);assert.equal(g.recipes.length,6);assert.equal(g.checkedAt,'2026-10-28');assert.equal(g.currency,'PKR');
 assert.equal(readFileSync('data/food-guide.json','utf8'),readFileSync('../forge_fitness/assets/food-guide.json','utf8'));
 const ids=new Set(g.sources.map(s=>s.id));for(const f of [...g.foods,...g.recipes]){assert(f.portion&&f.notes);assert(f.priceLow>=0&&f.priceHigh>=f.priceLow);assert(f.protein>=0&&f.calories>0);assert(f.sourceIds.length);assert(f.sourceIds.every(id=>ids.has(id)));}
 assert.match(p.prices.chana.basis,/whole/i);assert.match(p.prices.chicken.basis,/boneless/i);assert.equal(p.prices.chicken.low,1173);assert.equal(p.prices.chicken.high,1173);
 const rice=g.foods.find(f=>f.id==='rice');assert.equal(rice.calories,260);assert.equal(rice.priceLow,7.4);assert.equal(rice.priceHigh,13.4);assert.match(rice.notes,/67 g dry/);
 const roti=g.foods.find(f=>f.id==='roti');assert.equal(roti.calories,204);assert.equal(roti.priceLow,6.6);assert.match(roti.notes,/homemade ingredient cost/);
 assert.equal(g.foods.find(f=>f.id==='oil').protein,0);
});
test('each food has a bundled licensed photograph and meals show their ingredients',()=>{
 for(const food of g.foods){assert.equal(food.images.length,1,food.id);const image=food.images[0];assert.equal(image.id,food.id);assert(image.title&&image.author&&image.license);assert.match(image.sourceUrl,/^https:\/\//);assert.match(image.licenseUrl,/^https:\/\//);const bytes=readFileSync('../forge_fitness/'+image.asset);assert.equal(createHash('sha256').update(bytes).digest('hex'),image.sha256);assert(bytes.length>1000&&bytes.length<350000);}
 for(const meal of g.recipes)assert.deepEqual(meal.images.map(image=>image.id),meal.parts.map(part=>part[0]));
});
