// iOS 原生 App 的規則核心：把網頁版的酒譜、推薦、離線劇本、翻譯、安全規則原封不動打包，給 JavaScriptCore 跑（不是 WebView）。
// 打包：node tools/build_core.mjs → App/Data/core.js（esbuild IIFE，globalThis.BarCore）。規則來源 Gaming/AceBartender/public/js。
// Swift 只呼叫 BarCore.call(名稱, 參數 JSON) → 回傳 JSON 字串，所有介面都在 SwiftUI。
import { RECIPES, BY_ID, CATS, BASES, TAGS, GLASSES, TECHS, PANTRY, BASICS, INFUSION_RULES, isAlcoholic, applyTweak, cleanTweak, pantryMissing, canMake, nextBottle } from '../../AceBartender/public/js/recipes.js';
import { BARTENDERS, BT_IDS, bt, specialty } from '../../AceBartender/public/js/bartenders.js';
import * as E from '../../AceBartender/public/js/engine.js';
import { ROLE_COLOR } from '../../AceBartender/public/js/glass.js';
import { mockChat, mockReport } from '../../AceBartender/public/js/mockllm.js';
import { detectCrisis, RESOURCES, STOP_LINE } from '../../AceBartender/public/js/safety.js';
import { T, loc, btName, btText, sayOf, changesText, LANGS, LANG_NAMES, setLangCode, register } from '../../AceBartender/public/js/i18n.js';
import en from '../../AceBartender/public/i18n/data.en.js';
import ja from '../../AceBartender/public/i18n/data.ja.js';
import ko from '../../AceBartender/public/i18n/data.ko.js';
import es from '../../AceBartender/public/i18n/data.es.js';
import NATIVE from '../tools/native_strings.json';

register('en', en); register('ja', ja); register('ko', ko); register('es', es);
const lg = l => (LANGS.includes(l) ? l : 'zh');
// 原生介面多出來的字串（網頁沒有）：native_strings.json，人工翻譯
const tr = (s, vars, l) => {
  l = lg(l);
  let o = l === 'zh' ? s : NATIVE[s]?.[l] ?? T(s, null, l);
  if (vars) for (const [k, v] of Object.entries(vars)) o = o.split(`{${k}}`).join(v);
  return o;
};
const label = (table, k, l) => tr(table[k] || k, null, l);

// 杯子插圖要的資料：杯型、酒色、冰、氣泡、裝飾種類（裝飾用中文正本判斷，跟網頁 glass.js 一樣）
function garnishKind(g = '') {
  if (/薄荷|羅勒|百里香|迷迭/.test(g)) return 'herb';
  if (/櫻桃/.test(g)) return 'cherry';
  if (/橄欖/.test(g)) return 'olive';
  if (/柳橙|橘/.test(g)) return 'orange';
  if (/萊姆/.test(g)) return 'lime';
  if (/葡萄柚/.test(g)) return 'grapefruit';
  if (/檸檬|柑橘/.test(g)) return 'lemon';
  return '';
}
const art = r => ({ glass: GLASSES[r.glass] ? r.glass : 'rocks', color: r.color, ice: !/不加冰/.test(r.ice), fizzy: r.tags.includes('fizzy'), garnish: garnishKind(r.garnish) });
function extraTool(r) { const s = r.ingredients.map(i => i.n).join(); return r.infusion ? 'jar' : /紅酒|波特/.test(s) ? 'redwine' : /白酒|氣泡酒|香檳/.test(s) ? 'whitewine' : /鳳梨/.test(s) ? 'pineapple' : /草莓/.test(s) ? 'strawberry' : /水蜜桃|白桃/.test(s) ? 'peach' : /芒果/.test(s) ? 'mango' : /西瓜/.test(s) ? 'watermelon' : /荔枝/.test(s) ? 'lychee' : /葡萄柚/.test(s) ? 'grapefruit' : /蘋果/.test(s) ? 'apple' : /辣椒/.test(s) ? 'chili' : /薑/.test(s) ? 'ginger' : /茶/.test(s) ? 'teapot' : /檸檬/.test(s) ? 'lemon' : /萊姆/.test(s) ? 'lime' : /蜂蜜/.test(s) ? 'honey' : /蛋白/.test(s) ? 'egg' : /薄荷/.test(s) ? 'mint' : 'bottle'; }
const MAKE = {
  shake: { tools: ['jigger', 'ice', 'shaker'], txt: ['量好比例', '加滿冰塊', '用力搖', '濾進杯子'] },
  stir: { tools: ['jigger', 'mixglass', 'barspoon'], txt: ['量好比例', '加冰', '慢慢攪拌', '濾進杯子'] },
  build: { tools: ['ice', 'jigger', 'barspoon'], txt: ['杯子裝滿冰', '依序倒進去', '輕輕攪一下'] },
  muddle: { tools: ['muddler', 'ice', 'barspoon'], txt: ['放進杯底', '輕輕搗壓', '加冰', '攪一下'] },
  blend: { tools: ['jigger', 'ice', 'shaker'], txt: ['材料進果汁機', '加冰', '打到綿密'] },
};
const full = (id, tweak) => { const b = BY_ID[id]; if (!b) return null; return tweak ? applyTweak(b, cleanTweak(b, tweak)) : b; };

function recipeView(id, tweak, l) {
  const base = full(id, tweak); if (!base) return null;
  const r = loc(base, l);
  const M = MAKE[base.tech] || MAKE.build;
  return {
    id: base.id, name: r.name, en: base.en, nameZh: base.name, cat: base.cat, catLabel: label(CATS, base.cat, l), base: base.base, baseLabel: label(BASES, base.base, l),
    tags: base.tags.map(t => label(TAGS, t, l)), str: base.str, level: base.level, color: base.color,
    glass: base.glass, glassLabel: label(GLASSES, base.glass, l), ice: r.ice, tech: base.tech, techLabel: label(TECHS, base.tech, l),
    ingredients: r.ingredients.map(i => ({ n: i.n, ml: i.ml ?? null, amt: i.amt ?? null, role: i.role, color: ROLE_COLOR[i.role] || '#b5a78c' })),
    steps: r.steps, garnish: r.garnish, home: r.home, why: r.why, zero: r.zero, note: r.note || '',
    source: { label: tr(base.source?.label || '', null, l), url: base.source?.url || '' },
    official: !!base.official, inspired: !!base.inspired, orig: !!base.orig, tweaked: !!base.tweaked, tweak: base.tweak || null, changes: base.changes?.length ? changesText(base, l) : [],
    infusion: r.infusion ? { what: r.infusion.what, ratio: r.infusion.ratio, time: r.infusion.time, strain: r.infusion.strain, keep: r.infusion.keep, warn: r.infusion.warn || '' } : null,
    alcoholic: isAlcoholic(base), art: art(base),
    firstMain: (r.ingredients.find(i => i.role !== 'top' && i.role !== 'other')?.n || '').replace(/（.*）|\(.*\)/, ''),
    make: { tools: [extraTool(base), ...M.tools].slice(0, 4), steps: M.txt.map(x => tr(x, null, l)) },
  };
}
const recipeText = (id, tweak, l) => {
  const r = recipeView(id, tweak, l);
  return `【${r.name} ${r.en}】${r.tweaked ? `（${tr('微調版', null, l)}）` : ''}\n${r.ingredients.map(i => `${i.n} ${i.ml ? i.ml + 'ml' : i.amt}`).join('\n')}\n${tr('杯型', null, l)}：${r.glassLabel}／${tr('冰', null, l)}：${r.ice}\n${r.steps.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n${tr('裝飾', null, l)}：${r.garnish}\n${tr('在家替代方案', null, l)}：${r.home}${r.infusion ? `\n${tr('祕密配方', null, l)}（${r.infusion.what}）：${r.infusion.ratio}；${r.infusion.time}；${r.infusion.keep}` : ''}`;
};
const footer = l => `${tr('飲酒過量，有害健康。禁止酒駕。未滿 18 歲請勿飲酒。', null, l)}\n— ${tr('王牌酒保', null, l)}`;

function btView(id, l) {
  const b = bt(id), s = specialty(b);
  return {
    id, name: btName(b, l), title: btText(b, 'title', l), blurb: btText(b, 'blurb', l), age: b.age, gender: b.gender, ageBand: b.ageBand, img: b.img,
    bio: b.bio[l] || b.bio.en || b.bio.zh,
    spec: { cats: s.cats.map(c => label(CATS, c, l)), tags: s.tags.map(t => label(TAGS, t, l)), avoid: s.avoid.map(t => label(TAGS, t, l)), str: s.str, strLabel: tr(s.str <= 2 ? '淡' : s.str <= 3 ? '適中' : '烈', null, l), signature: s.signature },
  };
}

const API = {
  langs: () => ({ langs: [...LANGS], names: LANG_NAMES }),
  meta: ({ lang }) => ({
    cats: Object.keys(CATS).map(k => ({ k, label: label(CATS, k, lang) })), bases: Object.keys(BASES).map(k => ({ k, label: label(BASES, k, lang) })),
    pantry: PANTRY.map(p => ({ id: p.id, name: tr(p.name, null, lang) })), basics: BASICS.map(([k, v]) => ({ k: tr(k, null, lang), v: tr(v, null, lang) })),
    infusionRules: INFUSION_RULES.map(x => tr(x, null, lang)), btIds: BT_IDS, waterAfter: E.WATER_AFTER, textMax: E.TEXT_MAX, total: RECIPES.length,
    chips: Object.fromEntries([['base', E.CHIPS_BASE], ['drink', E.CHIPS_DRINK], ['zero', E.CHIPS_ZERO]].map(([k, a]) => [k, a.map(([lab, text]) => ({ label: tr(lab, null, lang), text: tr(text, null, lang) }))])),
  }),
  t: ({ s, vars, lang }) => tr(s, vars, lang),
  tMany: ({ list, lang }) => Object.fromEntries(list.map(s => [s, tr(s, null, lang)])),
  bartenders: ({ lang }) => BT_IDS.map(id => btView(id, lang)),
  greet: ({ bt: id, lang }) => { const a = sayOf(bt(id), 'greet', lg(lang)); return a[Math.floor(Math.random() * a.length)]; },
  recipe: ({ id, tweak, lang }) => recipeView(id, tweak, lang),
  recipes: ({ ids, tweaks, lang }) => ids.map(id => recipeView(id, tweaks?.[id] || null, lang)).filter(Boolean),
  list: ({ lang }) => RECIPES.map(base => { const r = loc(base, lang); return { id: base.id, name: r.name, en: base.en, cat: base.cat, base: base.base, inspired: !!base.inspired, alcoholic: isAlcoholic(base), art: art(base), tags: base.tags.slice(0, 3).map(t => label(TAGS, t, lang)), find: `${base.name}${r.name}${base.en}${label(BASES, base.base, lang)}${BASES[base.base]}${base.tags.map(t => label(TAGS, t, lang) + TAGS[t]).join('')}${r.ingredients.map(i => i.n).join('')}${base.ingredients.map(i => i.n).join('')}`.toLowerCase() }; }),
  chat: ({ req }) => mockChat({ ...req, lang: lg(req.lang) }),
  report: ({ req }) => mockReport({ ...req, lang: lg(req.lang) }),
  zeroPick: ({ text, bt: id, served }) => E.recommend(text, id, { served: served || [], zero: true })[0].id,
  crisis: ({ text }) => detectCrisis(text),
  help: ({ lang }) => ({ ...(RESOURCES[lg(lang)] || RESOURCES.en), stop: STOP_LINE[lg(lang)] || STOP_LINE.en }),
  rapport: ({ n, lang }) => tr(E.rapport(n), null, lang),
  servedAlcohol: ({ served }) => served.filter(id => BY_ID[id] && isAlcoholic(BY_ID[id])).length,
  isAlcoholic: ({ id }) => !!BY_ID[id] && isAlcoholic(BY_ID[id]),
  exists: ({ id }) => !!BY_ID[id],
  cleanTweak: ({ id, tweak }) => (BY_ID[id] && tweak ? cleanTweak(BY_ID[id], tweak) : null),
  cabinet: ({ have, zeroOnly, lang }) => { const can = RECIPES.filter(r => canMake(r, have) && (!zeroOnly || r.cat === 'zero')).map(r => r.id), nb = nextBottle(have); return { can, next: nb ? { name: tr(nb.name, null, lang), gain: nb.gain } : null }; },
  missing: ({ id, have, lang }) => pantryMissing(BY_ID[id], have).map(x => tr(x, null, lang)),
  recipeText: ({ id, tweak, lang }) => `${recipeText(id, tweak, lang)}\n${footer(lang)}`,
  nightText: ({ items, lang }) => `${tr('今晚喝過的調酒', null, lang)}\n\n${items.map(x => recipeText(x.id, x.tweak, lang)).join('\n\n')}\n\n${footer(lang)}`,
  name: ({ id, lang }) => (BY_ID[id] ? loc(BY_ID[id], lang).name : ''),
};

globalThis.BarCore = {
  version: 1,
  call(name, json) {
    try {
      const args = json ? JSON.parse(json) : {};
      if (args.lang) setLangCode(lg(args.lang));
      const out = API[name](args);
      return JSON.stringify({ ok: true, v: out === undefined ? null : out });
    } catch (e) { return JSON.stringify({ ok: false, error: String(e && e.stack || e) }); }
  },
};
