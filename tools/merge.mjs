// Une los catálogos extraídos (out/A.json, out/B.json, out/G.json) con productos.js.
// - Davey (A, B): reemplaza los productos A-/B- de la web por los del catálogo nuevo (sin agotados),
//   con precio = ¥ / 6 + 20 %.
// - Canaima (G): agrega iluminación y electricidad; quita los productos viejos que repite.
// node merge.mjs
import fs from "fs";
const SITE = "..";
const src = fs.readFileSync(`${SITE}/productos.js`, "utf8");
const window = {}; eval(src.replace("window.PRODUCTOS", "window.PRODUCTOS"));
const web = window.PRODUCTOS;
const read = p => JSON.parse(fs.readFileSync(p, "utf8"));

const key = s => String(s).toLowerCase().replace(/[\s*,.]/g, "");
const old = web.filter(p => /^[AB]-/.test(p.id));
const catByCode = new Map(old.map(p => [key(p.c), p.cat]));
const catByName = new Map(old.map(p => [p.n.toLowerCase(), p.cat]));
const NAMES = { A: "Hogar, cocina y decoración", B: "Variedades, mascotas y juguetes" };
const REP = /torta|pastel|reposter|ponqu|galleta|donas|capacillo|boquilla|cupcake|para pizza|hornear|rodillo|cucharas medidoras|sierra para pan/i;
const TEC = /cargador|cable (micro|tipo c|usb|dvd|de sonido)|audifono|pendrive|teclado|mouse|porta telefono|calculadora|\bups\b|control para aire/i;
const REMOTES = /^contro?l? (de tv|universal)/i;
const precio = y => Math.round(y / 6 * 1.2 * 100) / 100;

const davey = [];
for (const pre of ["A", "B"]) for (const i of read(`out/${pre}.json`)) {
  if (i.agotado || !i.img || REMOTES.test(i.nombre)) continue;
  const n = i.nombre.replace(/\s+/g, " ").trim();
  const flat = n.normalize("NFD").replace(/[̀-ͯ]/g, "");
  const cat = catByCode.get(key(i.codigo)) || catByName.get(n.toLowerCase()) ||
    (REP.test(flat) ? "Repostería" : TEC.test(flat) ? "Tecnología" : NAMES[pre]);
  const o = { id: i.id, n, c: i.codigo, cat, img: i.img };
  if (i.presentacion) o.p = i.presentacion;
  if (i.bulto) o.b = i.bulto;
  if (i.unidades.length) o.u = i.unidades;
  if (i.precio != null) o.pr = precio(i.precio);
  davey.push(o);
}

// Productos viejos de Iluminación que el catálogo Canaima trae con mejor foto y código
const REPLACED = /^(Lámpara larga Amanerluz 36W|Bombillo recargable Amanerluz 18W|Bombillo Amanerluz (9|12|18)W multi|Panel redondo Amanerluz 24W)$/;
const canaima = read("out/G.json").map(i => ({ id: i.id, n: i.nombre, c: i.codigo, cat: i.cat, sub: i.sub, img: i.img, p: `Se vende por ${i.unidad.toLowerCase()}`, u: [i.unidad, ...(i.unidad === "Bulto" ? [] : ["Bulto"])] }));

const keep = web.filter(p => !/^[ABG]-/.test(p.id) && !REPLACED.test(p.n));
const out = [...keep.filter(p => /^[NF]-/.test(p.id)), ...canaima, ...davey, ...keep.filter(p => !/^[NF]-/.test(p.id))];

// fotos: borra las viejas A/B/G y copia las nuevas
for (const f of fs.readdirSync(`${SITE}/img`)) if (/^[ABG]-/.test(f)) fs.unlinkSync(`${SITE}/img/${f}`);
for (const p of [...davey, ...canaima]) fs.copyFileSync(`out/${p.img}`, `${SITE}/${p.img}`);
const used = new Set(out.map(p => p.img));
for (const f of fs.readdirSync(`${SITE}/img`)) if (!used.has(`img/${f}`)) fs.unlinkSync(`${SITE}/img/${f}`);

const head = "// Generado desde los catálogos PDF. Campos: id, n=nombre, c=código, cat=catálogo, sub=categoría, p=presentación, b=bulto, u=unidades de venta, pr=precio en $";
fs.writeFileSync(`${SITE}/productos.js`, `${head}\nwindow.PRODUCTOS = ${JSON.stringify(out).replace(/\},\{/g, "},\n{")};\n`);
const count = {}; out.forEach(p => count[p.cat] = (count[p.cat] || 0) + 1);
console.log("total", out.length, count, "con precio", out.filter(p => p.pr != null).length,
  "faltan fotos", out.filter(p => !fs.existsSync(`${SITE}/${p.img}`)).length,
  "quitados por Canaima", web.filter(p => REPLACED.test(p.n)).map(p => p.n));
