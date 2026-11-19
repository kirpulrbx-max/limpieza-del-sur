// node serve.mjs [carpeta] [puerto]  -> servidor local para probar la página
import http from "http";
import fs from "fs";
import path from "path";
const root = path.resolve(process.argv[2] || ".."), port = +process.argv[3] || 5600;
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css", ".png": "image/png", ".jpg": "image/jpeg" };
http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (p.endsWith("/")) p += "index.html";
  const f = path.join(root, path.normalize(p));
  if (!f.startsWith(root)) { res.writeHead(403); return res.end(); }
  fs.readFile(f, (e, d) => {
    if (e) { res.writeHead(404); return res.end("404"); }
    res.writeHead(200, { "content-type": types[path.extname(f)] || "application/octet-stream" }); res.end(d);
  });
}).listen(port, () => console.log("http://localhost:" + port));
