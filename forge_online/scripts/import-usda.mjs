import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
const dir=resolve('../forge_fitness/downloads/usda-sr-legacy/FoodData_Central_sr_legacy_food_csv_2018-04');
function row(line){const out=[];let item='',quoted=false;for(let i=0;i<line.length;i++){const c=line[i];if(c==='"'){if(quoted&&line[i+1]==='"'){item+='"';i++;}else quoted=!quoted;}else if(c===','&&!quoted){out.push(item);item='';}else item+=c;}out.push(item);return out;}
function table(file){const lines=readFileSync(resolve(dir,file),'utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/);const head=row(lines.shift());return lines.map(line=>Object.fromEntries(row(line).map((value,i)=>[head[i],value])));}
const foods=new Map(table('food.csv').map(f=>[f.fdc_id,{id:Number(f.fdc_id),name:f.description,calories:null,protein:null,carbs:null,fat:null,portions:[],nutrients:{}}]));
const labels=Object.fromEntries(table('nutrient.csv').map(n=>[n.id,{name:n.name,unit:n.unit_name}]));
for(const n of table('food_nutrient.csv')){const f=foods.get(n.fdc_id);if(!f||n.amount==='')continue;const amount=Number(n.amount);if(!Number.isFinite(amount)||amount<0)continue;f.nutrients[n.nutrient_id]=amount;const field={1008:'calories',1003:'protein',1005:'carbs',1004:'fat'}[n.nutrient_id];if(field)f[field]=amount;}
const units=Object.fromEntries(table('measure_unit.csv').map(u=>[u.id,u.name]));
for(const p of table('food_portion.csv')){const f=foods.get(p.fdc_id);if(!f||f.portions.length>=7||Number(p.gram_weight)<=0)continue;const unit=units[p.measure_unit_id];const label=[p.amount,unit&&unit!=='undetermined'?unit:'',p.modifier||p.portion_description].filter(Boolean).join(' ');f.portions.push({label,grams:Number(p.gram_weight)});}
const valid=[...foods.values()].filter(f=>['calories','protein','carbs','fat'].every(k=>f[k]!==null));
mkdirSync('data',{recursive:true});mkdirSync('public',{recursive:true});
const metadata={source:'USDA FoodData Central SR Legacy, April 2018',sourceUrl:'https://fdc.nal.usda.gov/download-datasets/',basis:'Nutrients per 100 g edible food. Serving weights from USDA food_portion.',count:valid.length,nutrientLabels:labels};
writeFileSync('public/food-catalog.json',JSON.stringify({...metadata,foods:valid}));
mkdirSync('public/catalog',{recursive:true});for(let i=0;i<valid.length;i+=200){writeFileSync('public/catalog/'+Math.floor(i/200)+'.json',JSON.stringify(valid.slice(i,i+200)));}
writeFileSync('data/catalog-basic.json',JSON.stringify(valid.map(({nutrients,...f})=>f)));
writeFileSync('data/catalog-info.json',JSON.stringify(metadata,null,2));
console.log(JSON.stringify({foods:valid.length,bytes:readFileSync('public/food-catalog.json').length,banana:valid.find(f=>f.id===173944),milk:valid.find(f=>/Milk, whole, 3.25% milkfat, with added vitamin D/.test(f.name))?.id}));


