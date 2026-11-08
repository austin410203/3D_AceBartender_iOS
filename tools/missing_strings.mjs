// 列出 Swift 裡 L("…") 用到、但網頁翻譯表和 native_strings.json 都沒有的字串
// 執行：node native/tools/missing_strings.mjs   （全部有翻才會印 0 missing）
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const NATIVE = JSON.parse(fs.readFileSync(path.join(here, 'native_strings.json'), 'utf8'));
const { T, register } = await import('../../AceBartender/public/js/i18n.js');
for (const l of ['en', 'ja', 'ko', 'es']) register(l, (await import(`../../AceBartender/public/i18n/data.${l}.js`)).default);
const dir = path.join(here, '../App');
const found = new Set();
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.swift'))) {
  for (const m of fs.readFileSync(path.join(dir, f), 'utf8').matchAll(/L\("([^"]*)"/g)) found.add(m[1]);
}
const miss = [...found].filter(s => /[㐀-鿿]/.test(s) && !['en', 'ja', 'ko', 'es'].every(l => NATIVE[s]?.[l] || T(s, null, l) !== s));
console.log(JSON.stringify(miss, null, 1));
console.log(found.size, 'strings,', miss.length, 'missing');
process.exit(miss.length ? 1 : 0);
