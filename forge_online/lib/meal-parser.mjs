// Quantity extraction and nutrition lookup. No paid AI and no invented food matches.
const round=n=>Math.round(n*10)/10;
const protect=s=>s.replace(/\b(?:without|no)\s+(?:added\s+)?(?:sugar|oil|butter)\b/g,match=>match.replaceAll(' ','_'));
const normalize=s=>s.toLowerCase().replace(/[’']/g,'').replace(/[,;+]/g,' and ').replace(/½/g,' 0.5 ').replace(/¼/g,' 0.25 ').replace(/¾/g,' 0.75 ').replace(/\b(\d+)\s*\/\s*(\d+)\b/g,(_,a,b)=>String(Number(a)/Number(b))).replace(/[^a-z0-9.\s]/g,' ').replace(/\s+/g,' ').trim();
const words={one:1,two:2,three:3,four:4,five:5,six:6,seven:7,eight:8,nine:9,ten:10,eleven:11,twelve:12,half:.5,ek:1,aik:1,do:2,teen:3,char:4,chaar:4,paanch:5,che:6,aath:8,nau:9,das:10};
const unitAliases={g:'g',gram:'g',grams:'g',kg:'kg',kilogram:'kg',kilograms:'kg',ml:'ml',milliliter:'ml',millilitres:'ml',l:'l',litre:'l',liter:'l',liters:'l',litres:'l',cup:'cup',cups:'cup',glass:'glass',glasses:'glass',bowl:'bowl',bowls:'bowl',plate:'plate',plates:'plate',piece:'piece',pieces:'piece',pcs:'piece',pc:'piece',slice:'slice',slices:'slice',tbsp:'tbsp',tablespoon:'tbsp',tablespoons:'tbsp',tsp:'tsp',teaspoon:'tsp',teaspoons:'tsp',serving:'serving',servings:'serving',stick:'piece',sticks:'piece',handful:'handful',handfuls:'handful',packet:'packet',packets:'packet',pack:'packet',packs:'packet',bottle:'bottle',bottles:'bottle',oz:'oz',ounce:'oz',ounces:'oz'};
const essential=[
 [173424,'Boiled eggs',['hard boiled eggs','hard boiled egg','boiled eggs','boiled egg','eggs boiled','egg boiled','ublay anday','ubla anda','anday','ande','anda','eggs','egg'],50,'piece',{cup:136,tbsp:8.5},'Large hard-boiled eggs, 50 g edible weight each; no added oil.'],
 [173423,'Fried eggs',['fried eggs','fried egg'],46,'piece',{},'USDA fried egg reference; added oil varies.'],
 [172187,'Scrambled eggs',['scrambled eggs','scrambled egg'],61,'piece',{cup:220},'USDA scrambled egg reference; recipe additions vary.'],
 [171265,'Milk',['whole milk','full cream milk','milk','doodh','dudh'],258,'glass',{cup:244,tbsp:15},'Whole cow milk assumed; glass is approximately 250 ml (258 g).',1.03],
 [173944,'Bananas',['bananas','banana','kelay','kela'],118,'piece',{cup:150},'One medium peeled banana is 118 g.'],
 [168878,'Cooked rice',['cooked white rice','boiled white rice','boiled rice','plain rice','cooked rice','white rice','chawal','rice'],158,'cup',{bowl:158,plate:316},'Cooked white rice, no extra oil; cup 158 g, plate 316 g.'],
 [171477,'Cooked chicken breast',['grilled chicken breast','roasted chicken breast','chicken breast','grilled chicken','plain chicken','chicken'],150,'serving',{piece:150,cup:140},'Cooked skinless chicken breast, 150 g serving; bone excluded.'],
 [168631,'Grilled beef steak',['grilled beef steak','beef steak','steak'],150,'piece',{},'Cooked grilled beef top-loin steak, 150 g; sauces excluded.'],
 [171284,'Plain yogurt',['plain yogurt','yoghurt','yogurt','dahi'],245,'cup',{bowl:245,tbsp:15},'Plain whole-milk yogurt; cup 245 g.'],
 [168191,'Dates',['medjool dates','dates','khajoor','khajur'],24,'piece',{},'Large Medjool dates, 24 g pitted each; smaller varieties weigh less.'],
 [168202,'Apples',['apples','apple','seb'],169,'piece',{},'Medium apple with skin, 169 g edible portion.'],
 [172688,'Whole-wheat bread',['whole wheat bread','wholemeal bread','brown bread','bread','toast'],32,'slice',{},'Whole-wheat bread assumed for unspecified bread, 32 g slice; toppings excluded. Name white bread explicitly if that is what you ate.'],
 [174924,'White bread',['bunnys white bread','bunes white bread','bunys white bread','bunnys bread','white bread','white toast'],29,'slice',{},'Approximate generic USDA white bread, 29 g slice; this is not verified Bunny’s or other branded-label nutrition. Check the packet for exact slice weight. Toppings excluded.'],
 [169655,'Sugar',['table sugar','sugar','cheeni'],4.2,'tsp',{tbsp:12.6,cup:200},'Granulated sugar, 4.2 g per teaspoon.'],
 [171413,'Olive oil',['olive oil'],13.5,'tbsp',{tsp:4.5},'Measured olive oil; 13.5 g per tablespoon.',.91],
 [173227,'Black tea',['unsweetened black tea','black tea','tea without milk'],237,'cup',{glass:250},'Black tea without milk or sugar.'],
 [170438,'Boiled potatoes',['boiled potatoes','boiled potato','plain potatoes','plain potato'],136,'piece',{cup:156},'Medium boiled potato, 136 g; no added fat.'],
 [172421,'Plain cooked lentils',['plain boiled lentils','boiled lentils','cooked lentils','lentils'],198,'cup',{bowl:198},'Boiled lentils without added oil; use daal for a prepared recipe.'],
 [168771,'Chewing gum',['regular chewing gum','bubble gum','bubblegum','chewing gum'],3,'piece',{},'Generic sugared chewing gum, 3 g stick; brand and piece size vary.'],
 [169882,'Sugar-free gum',['sugar free chewing gum','sugarless chewing gum','sugar free gum','sugarless gum'],2,'piece',{},'Generic sugarless gum, 2 g piece; not automatically zero calories.'],
];
export function createMealParser(catalog,regional=[]){
 const byId=new Map(catalog.map(f=>[f.id,f]));
 const foods=essential.map(([id,name,aliases,grams,unit,units,assumptions,density])=>({...byId.get(id),id,name,aliases,defaultPortion:{grams,unit,label:`1 ${unit}`},units,assumptions,density:density||1,source:'USDA reference'}));
 for(const f of regional){foods.push({...f,density:f.densityGramsPerMl||1,source:f.source||(f.kind==='recipe'?'Representative recipe estimate':'Food reference'),units:Object.fromEntries((f.portions||[]).map(p=>[p.unit,p.grams]))});}
 foods.push({id:'water',name:'Water',aliases:['plain water','pani','paani','water'],calories:0,protein:0,carbs:0,fat:0,defaultPortion:{grams:250,unit:'glass'},units:{glass:250,cup:250,bottle:500},density:1,assumptions:'Water glass 250 ml; bottle 500 ml unless you specify a volume.',source:'Hydration log'});
 const aliases=foods.flatMap(food=>(food.aliases||[food.name]).map(alias=>({alias:protect(normalize(alias)),food}))).sort((a,b)=>b.alias.length-a.alias.length||Number(b.food.source==='Your verified nutrition label')-Number(a.food.source==='Your verified nutrition label'));
 return function interpret(text,{selected=[]}={}){
  if(typeof text!=='string'||!text.trim()||text.length>1000||/-\s*\d/.test(text))return {needsClarification:true,question:'Tell me the food and a positive amount, for example “3 boiled eggs and a glass of milk”.',items:[],unresolved:[]};
  let value=normalize(text).replace(/\b(one|two|three|four|five|six|seven|eight|nine|ten|\d+) and (?:a )?half\b/g,(_,n)=>String((words[n]||Number(n))+.5)).replace(/(\d)([a-z])/g,'$1 $2').replace(/([a-z])(\d)/g,'$1 $2').replace(/\b(\d+)\s*x\b/g,'$1 ').replace(/\bquantity\s*(?:is\s*)?(\d+(?:\.\d+)?)/g,' qty $1 ');
  for(const [word,num]of Object.entries(words))value=value.replace(new RegExp('\\b'+word+'\\b','g'),String(num));
  // Negated ingredients are excluded, never silently added as foods.
  value=protect(value);
  const occupied=new Uint8Array(value.length),matches=[];
  for(const {alias,food}of aliases){let from=0,index;while((index=value.indexOf(alias,from))>=0){from=index+alias.length;if((index>0&&/[a-z0-9_]/.test(value[index-1]))||/[a-z0-9_]/.test(value[index+alias.length]||''))continue;if(occupied.slice(index,index+alias.length).some(Boolean))continue;occupied.fill(1,index,index+alias.length);matches.push({start:index,end:index+alias.length,food});}}
  matches.sort((a,b)=>a.start-b.start);
  const items=[],assumptions=[],unresolved=[];let waterMl=0;
  for(let i=1;i<matches.length;i++){if(!value.slice(matches[i-1].end,matches[i].start).trim())unresolved.push('Is this one named dish or separate foods? Add “and” between separate foods, or give the dish recipe.');}
  if(/\bbubbles?\b/.test(value)&&!matches.some(m=>/gum/.test(m.food.name)))unresolved.push('“Bubbles” could mean bubble gum or a packaged snack. Please name the product or say “bubble gum”.');
  for(let i=0;i<matches.length;i++){
   const m=matches[i],prefix=value.slice(i?matches[i-1].end:0,m.start).replace(/^\s*(?:qty|quantity|x)\s*\d+(?:\.\d+)?/,' '),suffix=value.slice(m.end,i+1<matches.length?matches[i+1].start:value.length);
   const tokens=prefix.split(/\s+/),numbers=[...prefix.matchAll(/(?:^|\s)(\d+(?:\.\d+)?)(?=\s|$)/g)],last=numbers.at(-1);
   let quantity=last?Number(last[1]):1,unit=tokens.map(t=>unitAliases[t]).filter(Boolean).at(-1)||m.food.defaultPortion?.unit||'serving';
   const after=suffix.match(/^\s*(?:qty|quantity|x)\s*(\d+(?:\.\d+)?)/)||(i===matches.length-1?suffix.match(/^\s*(\d+(?:\.\d+)?)(?:\s+([a-z]+))?/):null);if(after){quantity=Number(after[1]);if(after[2]&&unitAliases[after[2]])unit=unitAliases[after[2]];}
   if(!Number.isFinite(quantity)||quantity<=0||quantity>5000){unresolved.push('Use a positive amount for '+m.food.name+'.');continue;}
   const density=m.food.density||1;let grams;
   if(unit==='g')grams=quantity;else if(unit==='kg')grams=quantity*1000;else if(unit==='ml')grams=quantity*density;else if(unit==='l')grams=quantity*1000*density;else if(unit==='oz')grams=quantity*28.3495;
   else {let weight=m.food.units?.[unit]||(m.food.portions||[]).find(p=>p.unit===unit)?.grams;if(!weight&&(unit==='serving'||unit===m.food.defaultPortion?.unit||unit==='piece'))weight=m.food.defaultPortion?.grams;if(!weight){unresolved.push(`What size ${unit} of ${m.food.name}? Add its weight in grams.`);continue;}grams=quantity*weight;}
   if(!grams||grams>10000){unresolved.push('Check the portion for '+m.food.name+'.');continue;}
   if(m.food.id==='water'){waterMl+=Math.round(grams);continue;}
   const labelUnit=quantity===1||['g','ml','kg','l','oz'].includes(unit)?unit:unit==='glass'?'glasses':unit+'s';
   const item={foodId:m.food.id,name:m.food.name,quantity,unit,grams:round(grams),portion:`${quantity} ${labelUnit} · ${round(grams)} g`,source:m.food.source};
   for(const k of ['calories','protein','carbs','fat'])item[k]=round(m.food[k]*grams/100);
   items.push(item);assumptions.push(m.food.assumptions||`Reference ${m.food.defaultPortion?.label||'serving'}; recipes vary.`);
  }
  let remaining=[...value].map((c,i)=>occupied[i]?' ':c).join('');
  remaining=remaining.replace(/\b(?:without|no)_(?:added_)?(?:sugar|oil|butter)\b/g,' ').replace(/\b\d+(?:\.\d+)?\b/g,' ').replace(/\b(?:i|ive|had|have|just|ate|eat|eaten|drank|drink|drunk|consumed|today|please|log|add|my|me|for|breakfast|lunch|dinner|snack|a|an|the|and|with|plus|of|at|about|approximately|around|large|medium|small|qty|quantity|is|x|aur|maine|mein|ne|khaya|khaye|khai|piya|pi|liya|li|thin|thick|boneless|skinless)\b/g,' ');
  for(const unit of Object.keys(unitAliases))remaining=remaining.replace(new RegExp('\\b'+unit+'\\b','g'),' ');
  remaining=remaining.replace(/\s+/g,' ').trim();
  if(remaining&&!unresolved.length)unresolved.push(`I could not identify “${remaining}” reliably. Add the dish's ingredients, choose a food, or use a label.`);
  if(!items.length&&!waterMl&&!unresolved.length)unresolved.push('I could not match that food. Try its common name or add ingredient details.');
  const sums={calories:0,protein:0,carbs:0,fat:0};for(const item of items)for(const k of Object.keys(sums))sums[k]+=item[k];for(const k of Object.keys(sums))sums[k]=round(sums[k]);
  if(sums.calories>10000||['protein','carbs','fat'].some(k=>sums[k]>1500)||waterMl>10000)unresolved.push('That amount is unusually large. Check the quantities or log separate meals.');
  return {is_food:items.length>0,waterMl,needsClarification:unresolved.length>0,question:unresolved[0]||'',unresolved,items,...sums,name:items.map(i=>i.name).join(' + ').slice(0,100)||'Water',portion:items.map(i=>i.portion+' '+i.name).join('; ').slice(0,900),assumptions:[...new Set(assumptions)].join(' ').slice(0,950),source:'Food reference estimate',engine:'quantity-parser',original:text};
 };
}
