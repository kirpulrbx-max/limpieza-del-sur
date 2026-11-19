// node info.mjs a.pdf b.pdf ...  -> páginas y texto de cada página
import * as mupdf from "mupdf";
import fs from "fs";
for (const f of process.argv.slice(2)) {
  const doc = mupdf.Document.openDocument(fs.readFileSync(f), "application/pdf");
  const n = doc.countPages();
  console.log("=====", f.split(/[\\/]/).pop(), "pages:", n, "bounds:", doc.loadPage(0).getBounds().map(Math.round).join(","));
  for (let i = 0; i < n; i++) {
    const t = doc.loadPage(i).toStructuredText().asText().replace(/\s+/g, " ").trim();
    console.log(`--p${i + 1}: ${t.slice(0, 400)}`);
  }
}
