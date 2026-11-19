// node dump.mjs file.pdf page  -> bloques de imagen y líneas de texto con posición
import * as mupdf from "mupdf";
import fs from "fs";
const [f, p] = process.argv.slice(2);
const doc = mupdf.Document.openDocument(fs.readFileSync(f), "application/pdf");
const j = JSON.parse(doc.loadPage(+p - 1).toStructuredText("preserve-images").asJSON());
for (const b of j.blocks) {
  const bb = b.bbox; const r = [bb.x, bb.y, bb.x + bb.w, bb.y + bb.h].map(Math.round).join(",");
  if (b.type === "image") console.log("IMG", r);
  else for (const l of b.lines) console.log("TXT", [l.bbox.x, l.bbox.y, l.bbox.w, l.bbox.h].map(Math.round).join(","), "sz", Math.round(l.font?.size || 0), JSON.stringify(l.text));
}
