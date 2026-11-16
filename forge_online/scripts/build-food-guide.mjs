// Reproducible serving macros from the existing USDA catalogue; price provenance
// is maintained separately from nutrition and never claims a restaurant quote.
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
const catalog=JSON.parse(readFileSync('data/catalog-basic.json'));
const prices=JSON.parse(readFileSync('data/food-guide-price-sources.json'));
const imageSources=['data/food-images-protein.json','data/food-images-energy.json'].flatMap(path=>{
 if(!existsSync(path))return [];const data=JSON.parse(readFileSync(path));return Array.isArray(data)?data:data.images??data.entries??[];
});
const definitions=[
 ['eggs','Boiled eggs','2 large eggs · 100 g edible',173424,100,2/12,'Meat & eggs',true,false,'Whole eggs include yolks. Frying oil is extra.',['Egg']],
 ['chicken','Chicken breast','150 g cooked, skinless breast',171477,150,.2,'Meat & eggs',true,false,'Estimated from 200 g raw boneless breast at 75% cooked yield. Oil, sauces and sides are extra.',[]],
 ['masoor','Plain cooked masoor dal','1 cup · 198 g cooked',172421,198,.07,'Plant sources',true,false,'Cost assumes 70 g dry lentils yields 198 g cooked. Plain lentils; tadka and oil add calories.',[]],
 ['chana','Boiled chickpeas / chana','1 cup · 164 g cooked',173757,164,.065,'Plant sources',true,false,'Cost assumes 65 g dry whole chickpeas yields 164 g cooked. Chaat sauces, oil and sides are extra.',[]],
 ['milk','Whole milk','1 glass · 250 ml',171265,258,.25,'Dairy',true,true,'Whole cow milk reference at 3.25% fat, about 258 g per 250 ml. Buffalo milk and brands can differ.',['Milk']],
 ['yogurt','Plain dahi / yogurt','1 bowl · 200 g',171284,200,.2,'Dairy',true,false,'Plain, unsweetened whole-milk yogurt. Strained yogurt and local milk types differ.',['Milk']],
 ['peanuts','Peanuts','1 small handful · 30 g edible',172430,30,.03,'Plant sources',true,true,'Unsalted raw edible peanuts. Useful protein plus energy; not a lean protein portion.',['Peanut']],
 ['oats','Plain oats','60 g dry oats',173904,60,.06,'Plant sources',true,true,'Dry weight before adding water or milk. Milk, sugar and toppings are extra.',['Oats; check gluten cross-contact']],
 ['rice','Plain cooked rice','200 g cooked rice',168878,200,.067,'Plant sources',false,true,'Cost assumes 67 g dry rice yields 200 g cooked. Generic white rice nutrition; price uses IRRI rice. No oil or ghee included.',[]],
 ['roti','Homemade whole-wheat roti','2 medium roti · about 80 g cooked',168893,60,.06,'Plant sources',false,true,'Nutrition and cost from 60 g dry atta plus water. No oil or ghee. This is homemade ingredient cost, not a tandoor price.',['Wheat / gluten']],
 ['banana','Banana','1 medium banana · 118 g edible',173944,118,1/12,'Plant sources',false,true,'A useful carbohydrate snack with little protein. Fruit size varies.',[]],
 ['dates','Dried dates','40 g edible dates',171726,40,.04,'Plant sources',false,true,'Generic dried-date nutrition; variety and size vary. Good energy, little protein.',[]],
 ['potato','Boiled potatoes','250 g cooked, peeled',170440,250,.3,'Plant sources',false,true,'Cost allows about 300 g whole potatoes before peeling. No frying oil, butter or sauces.',[]],
 ['oil','Cooking oil','1 teaspoon · about 5 ml',172336,4.5,.005,'Plant sources',false,true,'Energy only: no protein. Measure a small amount in cooking; this is not a protein-food replacement.',[]],
];
const macros=['calories','protein','carbs','fat'];
const round=n=>Math.round(n*10)/10;
const foods=definitions.map(([id,name,portion,fdcId,grams,factor,group,proteinPick,caloriePick,notes,allergens])=>{
 const f=catalog.find(f=>f.id===fdcId),p=prices.prices[id==='roti'?'atta':id];
 if(!f)throw new Error('Missing nutrition '+id);
 return {id,name,portion,fdcId,grams,group,proteinPick,caloriePick,notes,allergens,...Object.fromEntries(macros.map(k=>[k,round(f[k]*grams/100)])),priceLow:p?round(p.low*factor):null,priceHigh:p?round(p.high*factor):null,priceFactor:factor,priceKey:id==='roti'?'atta':id,sourceIds:p?.sourceIds??[],priceBasis:p?.basis??'Price unavailable; check your shop.'};
});
const recipes=[
 {id:'egg-roti',name:'Eggs with roti',parts:[['eggs',1],['roti',1]],notes:'2 boiled eggs and 2 homemade roti. Add vegetables; no oil or sauces counted.'},
 {id:'dal-roti',name:'Dal with roti',parts:[['masoor',1],['roti',.5]],notes:'1 cup plain cooked masoor plus 1 homemade roti. Add vegetables; tadka/oil is extra.'},
 {id:'chana-dahi',name:'Chana with dahi',parts:[['chana',1],['yogurt',.5]],notes:'1 cup boiled chickpeas and 100 g plain yogurt. Lemon, vegetables and spices can be added; no sweet sauces counted.'},
 {id:'oats-milk',name:'Oats with milk',parts:[['oats',1],['milk',1]],notes:'60 g dry oats plus 250 ml whole milk, cooked with water as needed. No sugar or toppings included.'},
 {id:'banana-shake',name:'Banana, oats & peanut shake',parts:[['milk',1],['banana',1],['oats',.5],['peanuts',.5]],notes:'250 ml whole milk, 1 medium banana, 30 g oats and 15 g peanuts. Blend with water if needed; no added sugar. Contains milk and peanuts.'},
 {id:'chicken-rice',name:'Chicken with rice',parts:[['chicken',1],['rice',1]],notes:'150 g cooked chicken breast plus 200 g plain cooked rice. Add vegetables; oil and sauces are extra.'},
].map(r=>{
 const parts=r.parts.map(([id,servings])=>({food:foods.find(f=>f.id===id),servings}));
 return {...r,portion:'1 meal · ingredients below',group:parts.every(p=>p.food.group==='Plant sources')?'Plant sources':parts.some(p=>p.food.group==='Meat & eggs')?'Meat & eggs':'Dairy',proteinPick:true,caloriePick:true,allergens:[...new Set(parts.flatMap(p=>p.food.allergens))],...Object.fromEntries(macros.map(k=>[k,round(parts.reduce((s,p)=>s+p.food[k]*p.servings,0))])),priceLow:parts.every(p=>p.food.priceLow!=null)?round(parts.reduce((s,p)=>s+p.food.priceLow*p.servings,0)):null,priceHigh:parts.every(p=>p.food.priceHigh!=null)?round(parts.reduce((s,p)=>s+p.food.priceHigh*p.servings,0)):null,sourceIds:[...new Set(parts.flatMap(p=>p.food.sourceIds))],priceBasis:'Estimated home ingredient cost, excluding cooking fuel, spices, oil unless listed, and delivery.'};
});
const guide={version:1,checkedAt:prices.checkedAt,currency:'PKR',nutritionSource:{title:'USDA FoodData Central SR Legacy',url:'https://fdc.nal.usda.gov/download-datasets/'},sources:prices.sources,foods,recipes};
for(const food of foods)food.images=imageSources.filter(image=>image.id===food.id).map(image=>({...image,label:food.name}));
for(const recipe of recipes)recipe.images=recipe.parts.flatMap(([id])=>foods.find(food=>food.id===id).images);
mkdirSync('../forge_fitness/assets',{recursive:true});
for(const path of ['data/food-guide.json','../forge_fitness/assets/food-guide.json'])writeFileSync(path,JSON.stringify(guide,null,2)+'\n');
console.log('Built '+foods.length+' foods and '+recipes.length+' meal ideas with traceable portions and prices.');
