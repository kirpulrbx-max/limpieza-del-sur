// Une los catálogos extraídos (out/A.json, out/B.json, out/G.json, out/K.json) con productos.js.
// - Davey (A, B): reemplaza los productos A-/B- de la web por los del catálogo nuevo (sin agotados),
//   con precio = (¥ / 6) × 1.2.
// - Canaima (G): agrega iluminación y electricidad; quita los productos viejos que repite.
// - Corpexca (K): agrega iluminación Kingsbright, actualiza coincidencias y omite agotados.
// - Excel de Xavier: precio del Excel + 20 %; Navidad conserva los precios publicados en el PDF.
// node merge.mjs
import fs from "fs";
const SITE = "..";
const src = fs.readFileSync(`${SITE}/productos.js`, "utf8");
const window = {}; eval(src.replace("window.PRODUCTOS", "window.PRODUCTOS"));
const web = window.PRODUCTOS;
const read = p => JSON.parse(fs.readFileSync(p, "utf8"));
const precios = read("precios.json");

const key = s => String(s).toLowerCase().replace(/[\s*,.]/g, "");
const old = web.filter(p => /^[AB]-/.test(p.id));
const catByCode = new Map(old.map(p => [key(p.c), p.cat]));
const catByName = new Map(old.map(p => [p.n.toLowerCase(), p.cat]));
const idByCode = new Map();
for (const p of old.filter(p => p.c)) {
  const code = key(p.c);
  if (idByCode.has(code)) idByCode.set(code, "");
  else idByCode.set(code, p.id);
}
const idByName = new Map(old.map(p => [p.n.toLowerCase(), p.id]));
const nextIds = Object.fromEntries(["A", "B"].map(prefix => [
  prefix,
  Math.max(0, ...old.filter(p => p.id.startsWith(`${prefix}-`)).map(p => Number(p.id.slice(2)) || 0)),
]));
const claimedIds = new Set();
const stableId = (prefix, code, name) => {
  const match = (code && idByCode.get(key(code))) || idByName.get(name.toLowerCase());
  if (match && !claimedIds.has(match)) {
    claimedIds.add(match);
    return match;
  }
  const id = `${prefix}-${String(++nextIds[prefix]).padStart(4, "0")}`;
  claimedIds.add(id);
  return id;
};
const NAMES = { A: "Hogar, cocina y decoración", B: "Variedades, mascotas y juguetes" };
const REP = /torta|pastel|reposter|ponqu|galleta|donas|capacillo|boquilla|cupcake|para pizza|hornear|rodillo|cucharas medidoras|sierra para pan/i;
const TEC = /cargador|cable (micro|tipo c|usb|dvd|de sonido)|audifono|pendrive|teclado|mouse|porta telefono|calculadora|\bups\b|control para aire/i;
const REMOTES = /^contro?l? (de tv|universal)/i;
const precio = y => Math.round(y / 6 * 1.2 * 100) / 100;
const corpexcaMatches = {
  "KB-F20": { id: "F-0001", nombre: "Lámpara LED recargable Kingsbright 20W" },
  "KB-F30": { id: "F-0002", nombre: "Lámpara LED recargable Kingsbright 30W" },
  "KB-FD95": { id: "F-0003", nombre: "Lámpara LED recargable Kingsbright 50W" },
  "KB-BR22": { id: "F-0004", nombre: "Bombillo Kingsbright recargable socate 22W" },
  "KB-RLF50": { id: "F-0014" },
  "KB-RLF100": { id: "F-0015" },
  "KB-RLF200": { id: "F-0016" },
  "KB-A07": { id: "F-0034" },
  "KB-A09": { id: "F-0035" },
  "KB-A12": { id: "F-0036" },
  "KB-A15": { id: "F-0037" },
  "KB-G30": { id: "F-0038" },
  "KB-G40": { id: "F-0039" },
  "KB-G50": { id: "F-0040" },
  "KB-G60": { id: "F-0041" },
  "KB-AL05": { id: "F-0042" },
  "KB-AL07": { id: "F-0043" },
  "KB-AL09": { id: "F-0044" },
  "KB-AL12": { id: "F-0045" },
  "KB-AL15": { id: "F-0046" },
  "KB-RNS50": { id: "F-0047" },
  "KB-RNS100": { id: "F-0048" },
  "KB-RNS150": { id: "F-0049" },
  "KB-RNS200": { id: "F-0050" },
  "KB-RNS300": { id: "F-0051" },
};

const davey = [];
fs.mkdirSync("out/stable", { recursive: true });
let pizzaSpatulaVariant = 0;
for (const pre of ["A", "B"]) for (const i of read(`out/${pre}.json`)) {
  if (i.agotado || !i.img || REMOTES.test(i.nombre)) continue;
  let n = i.nombre.replace(/\s+/g, " ").trim();
  if (i.codigo === "XCJ461-6" && i.pagina === 156) {
    const sizes = ["34 x 16 cm", "40 x 20 cm"];
    n = `Espátula para pizza ${sizes[pizzaSpatulaVariant++] || ""}`.trim();
  }
  const flat = n.normalize("NFD").replace(/[̀-ͯ]/g, "");
  const cat = catByCode.get(key(i.codigo)) || catByName.get(n.toLowerCase()) ||
    (REP.test(flat) ? "Repostería" : TEC.test(flat) ? "Tecnología" : NAMES[pre]);
  const id = stableId(pre, i.codigo, n);
  const img = `img/${id}.jpg`;
  fs.copyFileSync(`out/${i.img}`, `out/stable/${id}.jpg`);
  const o = { id, n, c: i.codigo, cat, img };
  if (i.presentacion) o.p = i.presentacion;
  if (i.bulto) o.b = i.bulto;
  if (i.unidades.length) o.u = i.unidades;
  if (i.precio != null) o.pr = precio(i.precio);
  davey.push(o);
}

// Productos viejos de Iluminación que el catálogo Canaima trae con mejor foto y código
const REPLACED = /^(Lámpara larga Amanerluz 36W|Bombillo recargable Amanerluz 18W|Bombillo Amanerluz (9|12|18)W multi|Panel redondo Amanerluz 24W)$/;
const canaima = read("out/G.json").map(i => ({ id: i.id, n: i.nombre, c: i.codigo, cat: i.cat, sub: i.sub, img: i.img, p: `Se vende por ${i.unidad.toLowerCase()}`, u: [i.unidad, ...(i.unidad === "Bulto" ? [] : ["Bulto"])] }));
const corpexca = read("out/K.json").filter(i => !i.agotado).map(i => {
  const match = corpexcaMatches[i.codigo];
  const existing = match && web.find(p => p.id === match.id);
  const packageName = i.bulto.match(/por (bulto|bolsa|paquete)$/i)?.[1];
  const product = existing
    ? { ...existing, c: i.codigo, img: i.img }
    : {
      id: i.id,
      n: i.nombre,
      c: i.codigo,
      cat: "Iluminación y pilas",
      sub: i.sub,
      img: i.img,
      ...(i.bulto ? { b: i.bulto } : {}),
      u: ["Unidad", ...(packageName ? [packageName[0].toUpperCase() + packageName.slice(1)] : [])],
    };
  if (match?.nombre) product.n = match.nombre;
  // precio Corpexca por unidad: (¥ ÷ 6) × 1,20; los que están en el Excel se reemplazan más abajo
  if (i.precio != null) product.pr = precio(i.precio);
  if (i.bulto) product.b = i.bulto;
  if (packageName) product.u = ["Unidad", packageName[0].toUpperCase() + packageName.slice(1)];
  return product;
});
const corpexcaIds = new Set(Object.values(corpexcaMatches).map(match => match.id));
const navidadVariantIds = new Set(precios.navidadVariants.map(variant => variant.id));

const keep = web.filter(p => !/^[ABGK]-/.test(p.id) && !REPLACED.test(p.n) &&
  !corpexcaIds.has(p.id) && !navidadVariantIds.has(p.id));
const out = [...keep.filter(p => /^[NF]-/.test(p.id)), ...canaima, ...corpexca, ...davey, ...keep.filter(p => !/^[NF]-/.test(p.id))];

const byId = new Map(out.map(p => [p.id, p]));
for (const [id, basePrice] of Object.entries(precios.excel)) {
  const product = byId.get(id);
  if (!product) throw new Error(`No existe el producto del Excel ${id}`);
  product.pr = Math.round(basePrice * 1.2 * 100) / 100; // Excel de Xavier + 20 %
  const units = product.u || ["Unidad", "Docena", "Bulto"];
  product.u = ["Unidad", ...units.filter(unit => unit !== "Unidad")];
  if (product.p?.startsWith("Se vende por ")) {
    product.p = `Precio por unidad; ${product.p.toLowerCase()}`;
  }
}
for (const [id, entry] of Object.entries(precios.navidad)) {
  const product = byId.get(id);
  if (!product) throw new Error(`No existe el producto de Navidad ${id}`);
  product.pr = entry.price;
  if (entry.name) product.n = entry.name;
  if (entry.presentation) product.p = entry.presentation;
  if (entry.units) product.u = entry.units;
}
for (const variant of precios.navidadVariants) {
  const source = byId.get(variant.from);
  if (!source) throw new Error(`No existe el producto base de Navidad ${variant.from}`);
  const product = {
    ...source,
    id: variant.id,
    n: variant.name,
    p: variant.presentation,
    pr: variant.price,
    u: ["Unidad"],
  };
  byId.set(product.id, product);
  out.push(product);
}

// fotos: borra las viejas A/B/G/K y copia las nuevas
for (const f of fs.readdirSync(`${SITE}/img`)) if (/^[ABGK]-/.test(f)) fs.unlinkSync(`${SITE}/img/${f}`);
for (const p of [...canaima, ...corpexca]) fs.copyFileSync(`out/${p.img}`, `${SITE}/${p.img}`);
for (const p of davey) fs.copyFileSync(`out/stable/${p.id}.jpg`, `${SITE}/${p.img}`);
const used = new Set(out.map(p => p.img));
for (const f of fs.readdirSync(`${SITE}/img`)) if (!used.has(`img/${f}`)) fs.unlinkSync(`${SITE}/img/${f}`);

const head = "// Generado desde los catálogos PDF. Campos: id, n=nombre, c=código, cat=catálogo, sub=categoría, p=presentación, b=bulto, u=unidades de venta, pr=precio en $";
fs.writeFileSync(`${SITE}/productos.js`, `${head}\nwindow.PRODUCTOS = ${JSON.stringify(out).replace(/\},\{/g, "},\n{")};\n`);
const count = {}; out.forEach(p => count[p.cat] = (count[p.cat] || 0) + 1);
console.log("total", out.length, count, "con precio", out.filter(p => p.pr != null).length,
  "faltan fotos", out.filter(p => !fs.existsSync(`${SITE}/${p.img}`)).length,
  "quitados por Canaima", web.filter(p => REPLACED.test(p.n)).map(p => p.n),
  "productos Corpexca", corpexca.length,
  "precios Excel", Object.keys(precios.excel).length,
  "precios Navidad", Object.keys(precios.navidad).length);
