// SC=0.5 node render.mjs file.pdf outPrefix 2 3 ...  -> PNG de páginas
import * as mupdf from "mupdf";
import fs from "fs";
const [f, out, ...pages] = process.argv.slice(2);
const sc = +(process.env.SC || 0.9);
const doc = mupdf.Document.openDocument(fs.readFileSync(f), "application/pdf");
for (const p of pages) {
  const pix = doc.loadPage(+p - 1).toPixmap(mupdf.Matrix.scale(sc, sc), mupdf.ColorSpace.DeviceRGB, false, true);
  fs.writeFileSync(`${out}_p${p}.png`, pix.asPNG());
}
