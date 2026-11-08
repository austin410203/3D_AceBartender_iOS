// 把網頁版的規則（Gaming/AceBartender/public/js）打包成 iOS App 用的 App/Data/core.js（JavaScriptCore 執行，IIFE → globalThis.BarCore）。
// 執行：node tools/build_core.mjs   （esbuild 借用 Gaming/DramVine/node_modules；規則來源是 Gaming/AceBartender/public/js）
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
let esbuild;
for (const p of [path.join(here, '../node_modules/esbuild'), path.join(here, '../../DramVine/node_modules/esbuild'), path.join(here, '../../EatWhat/node_modules/esbuild')]) { try { esbuild = require(p); break; } catch { /* next */ } }
if (!esbuild) throw new Error('esbuild not found');
await esbuild.build({
  entryPoints: [path.join(here, '../core/entry.js')], bundle: true, format: 'iife', target: 'es2020', charset: 'utf8', minify: false, legalComments: 'none',
  outfile: path.join(here, '../App/Data/core.js'), banner: { js: '// 自動產生：node tools/build_core.mjs（來源 Gaming/AceBartender/public/js、core/entry.js），不要手改' },
});
console.log('core.js built');
