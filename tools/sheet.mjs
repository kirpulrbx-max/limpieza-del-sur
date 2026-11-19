// CELL=150 node sheet.mjs out.png cols img1 img2 ...  -> hoja de contactos para revisar fotos
import * as mupdf from "mupdf";
import fs from "fs";
const [out, colsS, ...files] = process.argv.slice(2);
const cols = +colsS, cell = +(process.env.CELL || 150), rows = Math.ceil(files.length / cols);
const doc = new mupdf.PDFDocument();
const xo = {};
let content = "";
files.forEach((f, i) => {
  const img = new mupdf.Image(fs.readFileSync(f));
  const w = img.getWidth(), h = img.getHeight(), k = (cell - 6) / Math.max(w, h);
  const x = (i % cols) * cell + 3, y = (rows - 1 - Math.floor(i / cols)) * cell + 3;
  xo["I" + i] = doc.addImage(img);
  content += `q ${w * k} 0 0 ${h * k} ${x} ${y} cm /I${i} Do Q 0.8 G ${x - 1} ${y - 1} ${cell - 4} ${cell - 4} re S\n`;
});
const resources = doc.newDictionary(), xd = doc.newDictionary();
for (const [k, v] of Object.entries(xo)) xd.put(k, v);
resources.put("XObject", xd);
doc.insertPage(-1, doc.addPage([0, 0, cols * cell, rows * cell], 0, resources, content));
fs.writeFileSync(out, doc.loadPage(0).toPixmap(mupdf.Matrix.identity, mupdf.ColorSpace.DeviceRGB, false, true).asPNG());
