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

// Productos de iluminación que estaban en otras secciones (incluye los socates)
const MOVE = {
  "C-0002": "Reflectores", "C-0003": "Reflectores",
  "C-0004": "Lámparas", "C-0005": "Lámparas", "C-0006": "Lámparas",
  "C-0007": "Iluminación recargable", "C-0008": "Iluminación recargable",
  "B-0011": "Lámparas de mesa", "B-0012": "Lámparas de mesa", "B-0013": "Lámparas de mesa",
  "B-0014": "Lámparas de mesa", "B-0015": "Lámparas de mesa", "B-0016": "Lámparas de mesa",
  "B-0017": "Lámparas de mesa", "B-0018": "Lámparas de mesa", "B-0019": "Lámparas de mesa",
  "B-0472": "Lámparas de mesa",
  "F-0031": "Socates", "G-0107": "Socates", "G-0108": "Socates", "G-0125": "Socates",
  "G-0126": "Socates", "G-0116": "Socates", "C-0271": "Socates",
  "A-0025": "Pilas", "A-0026": "Pilas", "A-0027": "Pilas", "A-0028": "Pilas", "A-0029": "Pilas",
  "A-0030": "Pilas", "A-0031": "Pilas", "A-0032": "Pilas", "A-0033": "Pilas", "A-0034": "Pilas",
  "A-0035": "Pilas", "A-0511": "Pilas",
};
for (const p of all) {
  p.n = p.n.replace(/\bAmerluz\b/g, "Amanerluz");
  if (MOVE[p.id]) { p.cat = CAT; p.sub = MOVE[p.id]; }
  // los kits de faro tienen el mismo nombre: se distinguen por el tipo de base (H1, H4, 9005...)
  const base = /^Kit de bombillo LED para faro/.test(p.n) && /^KB-(?:T15|L6S)-(\w+)$/.exec(p.c);
  if (base && !p.n.includes(`(${base[1]})`)) p.n += ` (${base[1]})`;
}
const removed = all.filter(p => isBulb(p) && !brand(p));
const list = all.filter(p => !removed.includes(p));

// orden de los Kingsbright: bombillos normales, decorativos y recargables
const subRank = { "Bombillos": 0, "Bombillos decorativos": 1, "Iluminación recargable": 2 };
const group = p =>
  isBulb(p) && brand(p) === "A" ? 0 :
  isBulb(p) && brand(p) === "K" ? 1 :
  p.sub === "Reflectores" || /^reflector/i.test(p.n) ? 2 : 3;
// en el resto, cada subcategoría queda junta (en el orden en que aparece primero)
const inCat = list.filter(p => p.cat === CAT);
const subFirst = new Map();
inCat.forEach((p, i) => { if (!subFirst.has(p.sub)) subFirst.set(p.sub, i); });
const ilum = inCat
  .map((p, i) => ({ p, i }))
  .sort((a, b) => group(a.p) - group(b.p) ||
    // dentro de los bombillos, primero los que tienen precio
    (group(a.p) <= 1 ? (a.p.pr == null) - (b.p.pr == null) : 0) ||
    (group(a.p) === 1 ? (subRank[a.p.sub] ?? 9) - (subRank[b.p.sub] ?? 9) : 0) ||
    (group(a.p) === 3 ? subFirst.get(a.p.sub) - subFirst.get(b.p.sub) : 0) || a.i - b.i)
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
