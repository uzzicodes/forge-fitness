import {env} from 'cloudflare:workers';
import {getChatGPTUser} from '../../chatgpt-auth';
import {makeService} from '../../../lib/service.mjs';
import catalog from '../../../data/catalog-basic.json';
import info from '../../../data/catalog-info.json';
import regional from '../../../data/pakistan-foods.json';
export const dynamic='force-dynamic';
const service=makeService(catalog,info,regional);
async function handle(request:Request){return service(request,env,await getChatGPTUser());}
export const GET=handle;
export const POST=handle;

