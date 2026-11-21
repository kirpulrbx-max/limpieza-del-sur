// Extrae productos de un catálogo Davey (Universal de Oriente): nombre, código, presentación, precio ¥ y foto.
// node davey.mjs catalogo.pdf PREFIJO salida.json carpeta_img
import * as mupdf from "mupdf";
import fs from "fs";
import { renderTrimmed } from "./trim.mjs";
const [f, prefix, outJson, imgDir] = process.argv.slice(2);
const doc = mupdf.Document.openDocument(fs.readFileSync(f), "application/pdf");
const UNITS = ["pieza", "paquete", "docena", "cajita", "caja", "bulto", "juego", "rollo", "par", "set", "bolsa", "metro", "kilo", "display", "tira"];
const clean = s => s.replace(/\s+/g, " ").trim();
const cap = s => s ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : s;
const items = [];
let n = 0;
fs.mkdirSync(imgDir, { recursive: true });
for (let pi = 1; pi < doc.countPages(); pi++) {
  const page = doc.loadPage(pi);
  const [, , W, H] = page.getBounds();
  const j = JSON.parse(page.toStructuredText("preserve-images").asJSON());
  const imgs = [], lines = [];
  for (const b of j.blocks) {
    const bb = b.bbox;
    if (b.type === "image") {
      const r = { x0: Math.max(0, bb.x), y0: Math.max(0, bb.y), x1: Math.min(W, bb.x + bb.w), y1: Math.min(H, bb.y + bb.h) };
      const edges = (bb.x < 3) + (bb.y < 3) + (bb.x + bb.w > W - 3) + (bb.y + bb.h > H - 3);
      if (edges < 2 && bb.w > 60 && bb.h > 60 && bb.w < W * 0.8) imgs.push(r);
    } else for (const l of b.lines) lines.push({ t: clean(l.text), x0: l.bbox.x, y0: l.bbox.y, x1: l.bbox.x + l.bbox.w, y1: l.bbox.y + l.bbox.h, sz: l.font?.size || 0 });
  }
  const cods = lines.filter(l => /^COD\b/i.test(l.t)).sort((a, b) => a.y0 - b.y0);
  for (const c of cods) {
    const code = clean(c.t.replace(/^COD\s*[:：.]?\s*/i, ""));
    const cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
    const prev = cods.filter(o => o !== c && o.y0 < c.y0 && Math.abs((o.x0 + o.x1) / 2 - cx) < 150).pop();
    const top = Math.max(prev ? prev.y1 + 40 : 0, c.y0 - 120);
    const title = lines.filter(l => l !== c && l.sz >= c.sz - 2.5 && !/^COD\b|靓|箱/i.test(l.t) && !UNITS.includes(l.t.toLowerCase()) &&
      l.y0 >= top - 2 && l.y1 <= c.y0 + 4 && Math.abs((l.x0 + l.x1) / 2 - cx) < 170 && !/[¥一⼀]/.test(l.t))
      .sort((a, b) => a.y0 - b.y0).map(l => l.t).join(" ");
    const near = lines.filter(l => l.y0 > c.y0 - 5 && l.y0 < c.y1 + 140 && Math.abs((l.x0 + l.x1) / 2 - cx) < 200);
    const yen = near.find(l => /¥/.test(l.t));
    const box = near.find(l => /[一⼀]\s*[大⼤]\s*箱/.test(l.t));
    const agotado = !yen || /agotad[oa]/i.test(yen.t);
    const pm = yen && /¥\s*[:：]?\s*([\d.,]+)/.exec(yen.t);
    // el punto separa miles ("1.050" = 1050) y la coma es decimal ("15,50" = 15.5)
    const num = pm ? pm[1].replace(/[.,]$/, "") : "";
    const precio = num ? parseFloat(/^\d{1,3}(\.\d{3})+(,\d+)?$/.test(num) ? num.replace(/\./g, "").replace(",", ".") : num.replace(",", ".")) : null;
    let pres = yen ? clean(yen.t.replace(/^.*?¥\s*[:：]?\s*[\d.,]*\s*/i, "")) : "";
    if (/agotad[oa]/i.test(pres)) pres = "";
    const bulto = box ? clean(box.t.replace(/[()（）]/g, "").replace(/^.*箱\s*/, "")) : "";
    const unidades = [...new Set(lines.filter(l => l.y0 > c.y1 && l.y0 < c.y1 + 160 && Math.abs((l.x0 + l.x1) / 2 - cx) < 200 && UNITS.includes(l.t.toLowerCase())).sort((a, b) => a.x0 - b.x0).map(l => cap(l.t)))];
    let best = null, bestD = 1e9;
    for (const im of imgs) {
      const d = Math.abs((im.y0 + im.y1) / 2 - cy) + (cy >= im.y0 - 20 && cy <= im.y1 + 20 ? 0 : 300);
      if (d < bestD) { bestD = d; best = im; }
    }
    const id = `${prefix}-${String(++n).padStart(4, "0")}`;
    let img = "";
    if (!agotado) {
      // sin bloque de imagen: recorta la caja de la izquierda a la altura del código
      const r = best && bestD < 400 ? [best.x0, best.y0, best.x1, best.y1] : [45, Math.max(0, c.y0 - 80), 285, Math.min(H, c.y0 + 135)];
      img = `img/${id}.jpg`;
      fs.writeFileSync(`${imgDir}/${id}.jpg`, renderTrimmed(page, r, 400).asJPEG(78));
    }
    items.push({ id, nombre: cap(title) || "(sin nombre)", codigo: code, presentacion: cap(pres), bulto: cap(bulto), unidades, agotado, precio, img, pagina: pi + 1 });
  }
}
fs.writeFileSync(outJson, JSON.stringify(items, null, 1));
console.log(prefix, "items:", items.length, "agotados:", items.filter(i => i.agotado).length, "sin precio (no agotado):", items.filter(i => !i.agotado && i.precio == null).length, "sin imagen:", items.filter(i => !i.agotado && !i.img).length);
