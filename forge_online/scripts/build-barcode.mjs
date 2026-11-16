import {build} from 'esbuild';
import {copyFileSync} from 'node:fs';
await build({entryPoints:['scripts/barcode-browser.mjs'],bundle:true,minify:true,format:'iife',platform:'browser',target:['safari15'],outfile:'public/vision/barcode.min.js',legalComments:'eof'});
copyFileSync('node_modules/@zxing/library/LICENSE','public/vision/ZXING-LICENSE.txt');
