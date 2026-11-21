// Ordena y limpia los bombillos del catálogo. Se corre después de merge.mjs:
//   node iluminacion.mjs
// - Elimina los bombillos que no son Kingsbright ni Amanerluz (en cualquier categoría).
// - En "Iluminación y pilas" pone primero los bombillos Amanerluz, después los Kingsbright,
//   después todos los reflectores y al final el resto, sin cambiar el orden dentro de cada grupo.
import fs from "fs";
const FILE = "../productos.js";
const src = fs.readFileSync(FILE, "utf8");
const window = {}; eval(src);
const all = window.PRODUCTOS;

const CAT = "Iluminación y pilas";
const isBulb = p => /^bombillo/i.test(p.n);
const brand = p => /kingsbright/i.test(p.n) ? "K" : /amanerluz/i.test(p.n) ? "A" : "";

for (const p of all) p.n = p.n.replace(/\bAmerluz\b/g, "Amanerluz");
const removed = all.filter(p => isBulb(p) && !brand(p));
const list = all.filter(p => !removed.includes(p));

// orden de los Kingsbright: bombillos normales, decorativos y recargables
const subRank = { "Bombillos": 0, "Bombillos decorativos": 1, "Iluminación recargable": 2 };
const group = p =>
  isBulb(p) && brand(p) === "A" ? 0 :
  isBulb(p) && brand(p) === "K" ? 1 :
  p.sub === "Reflectores" || /^reflector/i.test(p.n) ? 2 : 3;
const ilum = list.filter(p => p.cat === CAT)
  .map((p, i) => ({ p, i }))
  .sort((a, b) => group(a.p) - group(b.p) ||
    (group(a.p) === 1 ? (subRank[a.p.sub] ?? 9) - (subRank[b.p.sub] ?? 9) : 0) || a.i - b.i)
  .map(x => x.p);

const first = list.findIndex(p => p.cat === CAT);
const rest = list.filter(p => p.cat !== CAT);
const out = [...rest.slice(0, first), ...ilum, ...rest.slice(first)];

const head = src.slice(0, src.indexOf("\n"));
fs.writeFileSync(FILE, `${head}\nwindow.PRODUCTOS = ${JSON.stringify(out).replace(/\},\{/g, "},\n{")};\n`);
const used = new Set(out.map(p => p.img));
for (const p of removed) if (!used.has(p.img) && fs.existsSync(`../${p.img}`)) fs.unlinkSync(`../${p.img}`);
console.log("eliminados:", removed.map(p => `${p.id} ${p.n}`));
console.log("total:", out.length);
