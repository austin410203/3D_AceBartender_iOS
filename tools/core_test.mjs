// 在沒有瀏覽器的環境（像 JavaScriptCore）跑 core.js，逐一呼叫 Swift 會用到的 API → CORE TEST PASS
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const src = fs.readFileSync(path.join(here, '../App/Data/core.js'), 'utf8');
const ctx = vm.createContext({ console });   // 沒有 window / document / localStorage / fetch
vm.runInContext(src, ctx);
let fail = 0;
const ok = (c, m) => { console.log(c ? '  ok  ' : '  FAIL', m); if (!c) fail++; };
const call = (n, a = {}) => { const j = JSON.parse(ctx.BarCore.call(n, JSON.stringify(a))); if (!j.ok) console.log('   error', n, j.error.slice(0, 300)); return j.v; };
const LANGS = ['zh', 'en', 'ja', 'ko', 'es'];
ok(call('langs').langs.join() === LANGS.join(), '五種語言');
for (const lang of LANGS) {
  const m = call('meta', { lang });
  ok(m.cats.length === 7 && m.total >= 184 && m.chips.base.length >= 10 && m.pantry.length > 5, `${lang} meta`);
  const bts = call('bartenders', { lang });
  ok(bts.length === 4 && bts.every(b => b.name && b.bio && b.spec.signature.length), `${lang} 四位 Bartender`);
  const list = call('list', { lang });
  ok(list.length === m.total && list.every(r => r.name && r.art.color), `${lang} 酒單 ${list.length}`);
  const r = call('recipe', { id: 'negroni', lang });
  ok(r && r.ingredients.length === 3 && r.ingredients.every(i => i.ml) && r.steps.length >= 2 && r.make.steps.length >= 3, `${lang} 酒譜卡 ${r?.name}`);
  const t = call('recipe', { id: 'whiskey_sour', tweak: { sweet: -1, sour: 0, strength: 0, swaps: [] }, lang });
  ok(t.tweaked && t.changes.length, `${lang} 微調版 ${t.changes[0]}`);
  const inf = call('list', { lang }).find(x => x.cat === 'infusion');
  ok(call('recipe', { id: inf.id, lang }).infusion?.ratio, `${lang} 祕密配方`);
  const c = call('chat', { req: { kind: 'chat', bartender: 'zhou', lang, text: m.chips.base[0].text, served: [], pantry: [], hist: [], seed: 5 } });
  ok(c.recipe_id && call('exists', { id: c.recipe_id }), `${lang} 離線點酒 → ${c.recipe_id}`);
  const rep = call('report', { req: { kind: 'report', bartender: 'mei', lang, drinks: ['negroni', 'mojito'], served: ['negroni', 'mojito'], pantry: [], history: [] } });
  ok(rep.headline && rep.summary, `${lang} 離線小記`);
  ok(call('help', { lang }).items.length >= 2, `${lang} 求助資源`);
  ok(call('recipeText', { id: 'mojito', lang }).includes('ml'), `${lang} 分享文字`);
  ok(call('greet', { bt: 'lan', lang }).length > 3, `${lang} 招呼`);
}
ok(call('crisis', { text: 'quiero morir' }) && call('crisis', { text: '我不想活了' }) && !call('crisis', { text: 'un mojito por favor' }), '危機偵測（含西文）');
const es = call('chat', { req: { kind: 'chat', bartender: 'mei', lang: 'es', text: 'Tengo 16 años, ponme algo', served: [], pantry: [] } });
ok(es.drink_safety === 'minor' && !call('isAlcoholic', { id: es.recipe_id }), '西文未成年 → 無酒精');
const es2 = call('chat', { req: { kind: 'chat', bartender: 'lan', lang: 'es', text: 'Quiero algo con vino tinto', served: [], pantry: [], seed: 3 } });
ok(call('recipe', { id: es2.recipe_id, lang: 'es' }).cat === 'wine', `西文紅酒 → ${es2.recipe_id}`);
const es3 = call('chat', { req: { kind: 'chat', bartender: 'che', lang: 'es', text: 'Ponme un Negroni', served: [], pantry: [] } });
ok(es3.recipe_id === 'negroni', '西文點酒名');
ok(call('cabinet', { have: ['gin', 'citrus', 'syrup', 'soda'], zeroOnly: false, lang: 'zh' }).can.length >= 1, '我家酒櫃');
console.log(fail ? `CORE TEST FAIL (${fail})` : 'CORE TEST PASS');
process.exit(fail ? 1 : 0);
