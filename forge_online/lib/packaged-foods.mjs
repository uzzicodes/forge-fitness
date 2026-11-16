const fail=(message,status=400)=>Object.assign(new Error(message),{status});
const finite=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
export const cleanName=s=>String(s||'').toLowerCase().replace(/[’']/g,'').replace(/[^a-z0-9 ]/g,' ').replace(/\s+/g,' ').trim();
export function validBarcode(code){
 if(typeof code!=='string'||! /^(?:\d{8}|\d{12}|\d{13}|\d{14})$/.test(code))return false;
 const digits=[...code].map(Number),check=digits.pop();return (10-digits.reverse().reduce((n,d,i)=>n+d*(i%2?1:3),0)%10)%10===check;
}
export function offProduct(raw){
 if(!raw||!validBarcode(raw.code))return null;
 const n=raw.nutriments||{},values={calories:n['energy-kcal_100g']??(typeof n.energy_100g==='number'&&n.energy_unit==='kJ'?n.energy_100g/4.184:undefined),protein:n.proteins_100g,carbs:n.carbohydrates_100g,fat:n.fat_100g};
 if(!finite(values.calories,0,950)||['protein','carbs','fat'].some(k=>!finite(values[k],0,100))||values.protein+values.carbs+values.fat>105)return null;
 const brand=String(raw.brands||'').slice(0,80),title=String(raw.product_name||raw.product_name_en||'').trim();
 const named=title&&!/^(?:https?:\/\/|www\.)/i.test(title);
 return {id:'off-'+raw.code,barcode:raw.code,name:(named?title:(brand||'Packaged')+' product · '+raw.code).slice(0,100),brand,...values,servingGrams:finite(raw.serving_quantity,.1,1000)?raw.serving_quantity:null,servingLabel:String(raw.serving_size||'').slice(0,120),source:'Open Food Facts',sourceUrl:'https://world.openfoodfacts.org/product/'+raw.code,license:'ODbL 1.0',licenseUrl:'https://opendatacommons.org/licenses/odbl/1.0/',needsName:!named};
}
export function labelFood(body){
 if(!body||typeof body.name!=='string'||body.name.trim().length<2||body.name.length>100||!finite(body.basisGrams,.1,1000)||!finite(body.servingGrams,.1,1000)||!['serving','slice','piece'].includes(body.servingUnit))throw fail('Add the product name, label basis in grams, and serving weight.');
 if(body.barcode&&!validBarcode(body.barcode))throw fail('Check the barcode digits and check digit.');
 if(!finite(body.calories,0,9500)||['protein','carbs','fat'].some(k=>!finite(body[k],0,1000)))throw fail('Enter all four nutrition numbers from the label, including any printed zeros.');
 const scaled=Object.fromEntries(['calories','protein','carbs','fat'].map(k=>[k,body[k]*100/body.basisGrams]));
 if(scaled.calories>950||scaled.protein+scaled.carbs+scaled.fat>105)throw fail('Those values exceed the label weight. Check per-serving versus per-100 g values.');
 return {id:typeof body.id==='string'&&/^[a-zA-Z0-9-]{1,80}$/.test(body.id)?body.id:crypto.randomUUID(),name:body.name.trim(),barcode:body.barcode||'',...scaled,servingGrams:body.servingGrams,servingUnit:body.servingUnit,source:'Your verified nutrition label',assumptions:'Your saved label; '+body.servingGrams+' g per '+body.servingUnit+'. Check the current packet if its recipe or size changes.'};
}
export async function lookupProducts(db,query,barcode,fetcher=fetch){
 if(barcode&&!validBarcode(barcode))throw fail('Use the 8, 12, 13 or 14 barcode digits, including the check digit.');
 const q=cleanName(query);if(!barcode&&(q.length<2||q.length>80))throw fail('Search a brand or product name, or enter a barcode.');
 const key=barcode?'barcode:'+barcode:'search:'+q,now=Date.now();
 const cached=await db.prepare('SELECT data_json FROM product_lookup_cache WHERE cache_key=? AND expires_at>?').bind(key,now).first();
 if(cached)return JSON.parse(cached.data_json);
 const minute=new Date().toISOString().slice(0,16),budget=barcode?12:8;
 const reserved=await db.prepare('INSERT INTO ai_usage(user_id,day,count) VALUES(?,?,1) ON CONFLICT(user_id,day) DO UPDATE SET count=ai_usage.count+1 WHERE ai_usage.count<? RETURNING count').bind('__off_'+(barcode?'barcode':'search')+'__',minute,budget).first();
 if(!reserved)throw fail('Product lookup is busy. Wait a minute, or use a saved label; no Gemini request was used.',429);
 const fields='code,product_name,product_name_en,brands,nutriments,serving_quantity,serving_size';
 const url=new URL(barcode?'https://world.openfoodfacts.org/api/v2/product/'+barcode+'.json':'https://world.openfoodfacts.org/api/v2/search');url.searchParams.set('fields',fields);
 if(!barcode){url.searchParams.set('page_size','12');if(/^bunnys(?: bread)?$/.test(q))url.searchParams.set('brands_tags','bunnys');else url.searchParams.set('search_terms',q);}
 let r;try{r=await fetcher(url,{headers:{'User-Agent':'FORGE-Fitness/1.0 (https://forge-fitness-fuel.jazzylark16.chatgpt.site)'},signal:AbortSignal.timeout(15000)});}catch{throw fail('The free product database could not connect. Your saved labels still work.',503);}
 if(!r.ok&&r.status!==404)throw fail('The free product database is busy. Try later or enter the packet label.',r.status===429?429:503);
 let raw;try{raw=await r.json();}catch{throw fail('The product database returned an unreadable response. Try a saved label.',503);}const rows=barcode?(raw.product?[raw.product]:[]):Array.isArray(raw.products)?raw.products:[];
 const products=rows.slice(0,12).map(offProduct).filter(Boolean).filter(p=>!barcode||p.barcode.replace(/^0+/,'')===barcode.replace(/^0+/,''));
 const result={products,source:'Open Food Facts',license:'ODbL 1.0',note:'Community data: match the barcode and variant against your packet. Missing nutrition fields are not guessed.',incomplete:rows.length-products.length};
 await db.prepare('INSERT INTO product_lookup_cache(cache_key,data_json,expires_at) VALUES(?,?,?) ON CONFLICT(cache_key) DO UPDATE SET data_json=excluded.data_json,expires_at=excluded.expires_at').bind(key,JSON.stringify(result),now+(products.length?86400000:300000)).run();
 return result;
}
