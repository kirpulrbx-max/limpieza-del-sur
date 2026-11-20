// Extrae productos y fotos de catálogo de iluminación Kingsbright (Corpexca).
// node corpexca.mjs catalogo.pdf salida.json carpeta_img
import * as mupdf from "mupdf";
import fs from "fs";
import { draw } from "./trim.mjs";

const [file, outJson, imgDir] = process.argv.slice(2);
const doc = mupdf.Document.openDocument(fs.readFileSync(file), "application/pdf");
const clean = s => s.replace(/\s+/g, " ").trim();
const titleCase = s => s.toLowerCase()
  .replace(/^\s*\S/, c => c.toUpperCase())
  .replace(/\blamparas?\b/gi, word => `${word[0] === "L" ? "L" : "l"}ámpara${word.endsWith("s") ? "s" : ""}`)
  .replace(/\biluminacion\b/gi, word => `${word[0] === "I" ? "I" : "i"}luminación`)
  .replace(/\bled\b/gi, "LED")
  .replace(/\b(\d+)\s*w\b/gi, "$1W")
  .replace(/\b(\d+)\s*k\b/gi, "$1K")
  .replace(/\bac\b/gi, "AC")
  .replace(/\brgb\b/gi, "RGB");
const category = page => {
  if (page <= 3) return "Bombillos";
  if (page <= 5) return "Iluminación recargable";
  if (page === 6) return "Linternas";
  if (page === 7) return "Bombillos decorativos";
  if (page === 8) return "Cintas LED y accesorios";
  if (page === 9) return "Iluminación automotriz";
  if (page <= 12) return "Reflectores y lámparas";
  return "Paneles y plafones";
};

fs.mkdirSync(imgDir, { recursive: true });
const byCode = new Map();
for (let pageNumber = 2; pageNumber <= Math.min(15, doc.countPages()); pageNumber++) {
  const page = doc.loadPage(pageNumber - 1);
  const [, , width, height] = page.getBounds();
  const blocks = JSON.parse(page.toStructuredText("preserve-images").asJSON()).blocks;
  const lines = [], images = [];
  for (const block of blocks) {
    if (block.type === "image") {
      images.push(block.bbox);
      continue;
    }
    for (const line of block.lines) {
      lines.push({
        text: clean(line.text),
        x: line.bbox.x,
        y: line.bbox.y,
        w: line.bbox.w,
        h: line.bbox.h,
      });
    }
  }

  for (const codeLine of lines.filter(line => /^KB-[A-Z0-9][A-Z0-9-]*$/i.test(line.text))) {
    const cx = codeLine.x + codeLine.w / 2;
    const price = lines
      .filter(line => /^PRECIO UNIDAD\s*:/i.test(line.text) && line.y >= codeLine.y && line.y - codeLine.y < 55)
      .sort((a, b) => Math.abs(a.x + a.w / 2 - cx) - Math.abs(b.x + b.w / 2 - cx))[0];
    if (!price || Math.abs(price.x + price.w / 2 - cx) > 85) continue;

    const existing = byCode.get(codeLine.text);
    if (existing) continue;

    const belowCode = lines
      .filter(line => line.y >= codeLine.y + codeLine.h - 1 && line.y < price.y && Math.abs(line.x + line.w / 2 - cx) < 95)
      .sort((a, b) => a.y - b.y);
    const name = belowCode
      .filter(line =>
        !/^(?:UNIDAD|PRECIO|BULTO|BOLSA|PAQUETE|AGOTADO|AC\s*85\/265V)\b/i.test(line.text) &&
        !/NUEVO|新品/i.test(line.text)
      )
      .map(line => line.text)
      .join(" ");
    if (!name) continue;

    const exhausted = lines.some(line =>
      /AGOTADO/i.test(line.text) &&
      Math.abs(line.x + line.w / 2 - cx) < 90 &&
      Math.abs(line.y - codeLine.y) < 120
    );
    const packageLine = belowCode.find(line => /^UNIDAD\s+(BULTO|BOLSA|PAQUETE)\s*:/i.test(line.text));
    const pack = packageLine && /^UNIDAD\s+(BULTO|BOLSA|PAQUETE)\s*:\s*([\d.,]+)/i.exec(packageLine.text);
    const packageType = pack ? pack[1].toLowerCase() : "";
    const image = images
      .map(box => ({
        box,
        dx: Math.abs(box.x + box.w / 2 - cx),
        gap: codeLine.y - (box.y + box.h),
      }))
      .filter(candidate =>
        candidate.dx < 45 &&
        candidate.gap >= -8 &&
        candidate.gap < 20 &&
        candidate.box.w > 55 &&
        candidate.box.h > 45
      )
      .sort((a, b) => Math.abs(a.gap) - Math.abs(b.gap) || a.dx - b.dx)[0];

    const id = `K-${String(byCode.size + 1).padStart(4, "0")}`;
    let img = "";
    if (!exhausted) {
      const rect = image
        ? [image.box.x, image.box.y, image.box.x + image.box.w, image.box.y + image.box.h]
        : [Math.max(0, cx - 68), Math.max(0, codeLine.y - 105), Math.min(width, cx + 68), Math.max(0, codeLine.y - 10)];
      img = `img/${id}.jpg`;
      const scale = 520 / Math.max(rect[2] - rect[0], rect[3] - rect[1]);
      fs.writeFileSync(`${imgDir}/${id}.jpg`, draw(page, rect, scale).asJPEG(80));
    }

    byCode.set(codeLine.text, {
      id,
      nombre: `${titleCase(name)} Kingsbright`,
      codigo: codeLine.text,
      sub: category(pageNumber),
      bulto: pack ? `${pack[2]} unidades por ${packageType}` : "",
      agotado: exhausted,
      img,
      pagina: pageNumber,
    });
  }
}

const items = [...byCode.values()];
fs.writeFileSync(outJson, JSON.stringify(items, null, 1));
console.log("Corpexca:", items.length, "productos,", items.filter(item => item.agotado).length, "agotados,",
  items.filter(item => !item.agotado && !item.img).length, "sin foto");
