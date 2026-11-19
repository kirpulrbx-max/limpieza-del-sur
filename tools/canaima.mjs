// Catálogo Grupo Canaima (iluminación y electricidad).
// node canaima.mjs catalogo.pdf salida.json carpeta_img
// Cada producto: [página, código, nombre, se vende por, categoría, subcategoría].
// Foto: si la página tiene varios recuadros "CODIGO:" se usa el recuadro del código;
// si es una tabla de variantes, la parte de fotos sobre la tabla (compartida).
import * as mupdf from "mupdf";
import fs from "fs";
import { draw } from "./trim.mjs";
const [f, outJson, imgDir] = process.argv.slice(2);

const IL = "Iluminación y pilas", EL = "Electricidad";
const P = [];
const add = (page, unidad, cat, sub, ...rows) => rows.forEach(([c, n]) => P.push([page, c, n, unidad, cat, sub]));

add(2, "Paquete", IL, "Bombillos", ["REA18W", "Bombillo LED recargable de emergencia Amanerluz 18W"]);
add(3, "Bulto", IL, "Linternas", ["A607", "Linterna minera recargable Amanerluz 300W"], ["A608", "Linterna minera recargable Amanerluz 200W"]);
add(4, "Paquete", IL, "Bombillos", ["E14-5W", "Bombillo LED Amanerluz 5W (E14)"], ["E27-5W", "Bombillo LED Amanerluz 5W (E27)"], ["E27-9W", "Bombillo LED Amanerluz 9W (E27)"]);
add(5, "Paquete", IL, "Reflectores", ["ZDLD-200W", "Farola de puntos con cuencas Amanerluz 200W"], ["XFLD-50W", "Farola Pioneer Amanerluz 50W"]);
add(6, "Paquete", IL, "Lámparas", ["SQP2005", "Lámpara LED empotrable 5W"], ["SQP2009", "Lámpara LED empotrable 9W"], ["SQP2012", "Lámpara LED empotrable 12W"]);
add(7, "Paquete", IL, "Lámparas", ["LAM-IN100W", "Lámpara plafón industrial Amanerluz 100W"], ["LAM-IN150W", "Lámpara plafón industrial Amanerluz 150W"], ["LAM-IN200W", "Lámpara plafón industrial Amanerluz 200W"]);
add(8, "Cajita", IL, "Reflectores", ["SLZ100W", "Reflector LED Amanerluz 110V 100W"], ["SLZ200W", "Reflector LED Amanerluz 110V 200W"], ["SLZ300W", "Reflector LED Amanerluz 110V 300W"], ["CAL400W", "Reflector LED Amanerluz 110V 400W"]);
add(9, "Cajita", IL, "Reflectores", ["SLK50W", "Reflector LED Amanerluz multivoltaje 50W"], ["SLK100W", "Reflector LED Amanerluz multivoltaje 100W"], ["SLK200W", "Reflector LED Amanerluz multivoltaje 200W"]);
add(10, "Paquete", IL, "Reflectores", ["ZD50W-WH", "Reflector LED blanco 50W 110V"]);
add(10, "Cajita", IL, "Reflectores", ["RAL40W", "Reflector LED de socate E27 Amanerluz 40W"]);
add(11, "Cajita", IL, "Reflectores", ["RAL100WA", "Reflector LED de socate E27 Amanerluz 100W"], ["RAL200WA", "Reflector LED de socate E27 Amanerluz 200W"]);
add(12, "Paquete", IL, "Reflectores", ["MY300W", "Reflector LED de alta intensidad Amanerluz 300W"]);
add(13, "Paquete", IL, "Lámparas", ["LAMP-LA36W", "Lámpara LED larga Amanerluz 36W (120cm) 6500K"]);
add(14, "Paquete", IL, "Lámparas", ["LAMPLA-27W", "Lámpara LED larga Amanerluz 27W (90cm) 8000K"], ["LAMPLA-36W", "Lámpara LED larga Amanerluz 36W (120cm) 8000K"]);
add(15, "Paquete", IL, "Paneles", ["MB012R-M", "Panel redondo empotrado Amanerluz 12W"], ["MB024R-M", "Panel redondo empotrado Amanerluz 24W"], ["MB030R-M", "Panel redondo empotrado Amanerluz 30W"], ["MB045R-M", "Panel redondo empotrado Amanerluz 45W"]);
add(16, "Paquete", IL, "Paneles", ["MB040-R", "Lámpara redonda superficial Amanerluz 40W"]);
add(17, "Paquete", IL, "Lámparas", ["TAB-15W", "Lámpara ovalada de pared Amanerluz 15W"], ["TAB-20W", "Lámpara ovalada de pared Amanerluz 20W"]);
add(18, "Paquete", IL, "Lámparas", ["YAB-15W", "Lámpara redonda de pared Amanerluz 15W"]);
add(19, "Paquete", IL, "Paneles", ["MB012C-M", "Panel cuadrado empotrado Amanerluz 12W"], ["MB045C-M", "Panel cuadrado empotrado Amanerluz 45W"]);
add(20, "Paquete", IL, "Paneles", ["MB030-C", "Lámpara cuadrada superficial Amanerluz 30W"], ["MB040-C", "Lámpara cuadrada superficial Amanerluz 40W"]);
add(21, "Cajita", IL, "Lámparas", ["PAL50W", "Lámpara plafón Amanerluz 110V 50W"], ["PAL100W", "Lámpara plafón Amanerluz 110V 100W"]);
add(22, "Unidad", IL, "Lámparas", ["MG045", "Lámpara LED plegable tipo flor 45W (3 pétalos)"], ["MG060", "Lámpara LED plegable tipo flor 60W (4 pétalos)"], ["MG075", "Lámpara LED plegable tipo flor 75W (5 pétalos)"]);
add(23, "Paquete", IL, "Lámparas", ["LMS60W-PB", "Lámpara tipo manzana 60W"], ["LMS70W-PB", "Lámpara tipo manzana 70W"], ["LMS80W-PB", "Lámpara tipo manzana 80W"]);
add(24, "Bulto", IL, "Lámparas", ["LMS200W-C", "Lámpara de techo tipo manzana 200W"]);
add(25, "Paquete", IL, "Rieles", ["LAMR-10W", "Lámpara de riel Amanerluz 10W"]);
add(26, "Paquete", IL, "Rieles", ["RL-100", "Riel para lámpara Amanerluz 100cm"], ["RL-200", "Riel para lámpara Amanerluz 200cm"]);
add(27, "Paquete", IL, "Rieles", ["CONE-1", "Conector recto para riel"], ["CONE-L", "Conector en L para riel"], ["CONE-T", "Conector en T para riel"], ["CONE-X", "Conector en X para riel"]);
add(28, "Paquete", IL, "Bombillos", ["BAL-A10W", "Bombillo Amanerluz 110V 10W (azul)"], ["BAL-A15W", "Bombillo Amanerluz 110V 15W (azul)"], ["BAL-A50W", "Bombillo Amanerluz 110V 50W (azul)"], ["BAL-A60W", "Bombillo Amanerluz 110V 60W (azul)"]);
add(29, "Paquete", IL, "Bombillos", ["BAD15W", "Bombillo LED rojo Amanerluz multivoltaje 15W"]);
add(30, "Bulto", IL, "Bombillos", ...[5, 9, 12, 15, 18, 24].map(w => [`BBAL${w}W-50`, `Bombillo bulbo Amanerluz 110V ${w}W`]));
add(31, "Bulto", IL, "Bombillos", ["BBAD9W", "Bombillo bulbo Amanerluz multivoltaje 9W"], ...[12, 15, 18, 24].map(w => [`BBAD${w}W-50`, `Bombillo bulbo Amanerluz multivoltaje ${w}W`]));
add(32, "Paquete", EL, "Extensiones", ["EXR-3M", "Extensión Amanerluz con suiche 3m"], ["EXR-5M", "Extensión Amanerluz con suiche 5m"], ["EXR-7M", "Extensión Amanerluz con suiche 7m"]);
add(33, "Rollo", EL, "Cables", ["CB233-BL", "Cable SPT blanco 2x10 AWG (100m)"], ["CB234-BL", "Cable SPT blanco 2x12 AWG (100m)"], ["CB235-BL", "Cable SPT blanco 2x14 AWG (100m)"]);
const colores = { BL: "blanco", NG: "negro", RJ: "rojo", AM: "amarillo", AZ: "azul", VE: "verde" };
const cable = (page, base, name, cols) => add(page, "Rollo", EL, "Cables", ...cols.map(c => [`${base}-${c}`, `${name} ${colores[c]} (100m)`]));
cable(34, "CB8413", "Cable THW nylon 90° 14 AWG", ["AM", "AZ", "VE"]);
cable(35, "CB51414", "Cable THW 75° 14 AWG", ["NG", "RJ", "AM", "AZ", "VE"]);
cable(36, "CB51377", "Cable THW 75° 12 AWG", ["BL", "NG", "RJ", "AZ", "VE"]);
cable(37, "CB51370", "Cable THW 75° 10 AWG", ["BL", "NG", "RJ", "AM", "AZ", "VE"]);
cable(38, "CB51263", "Cable THW 75° 8 AWG", ["NG", "BL", "VE", "RJ", "AM"]);
cable(39, "CB51378", "Cable THW 75° 6 AWG", ["NG", "RJ", "BL"]);
add(40, "Cajita", EL, "Socates", ["SC1010", "Socate de cerámica"]);
add(40, "Paquete", EL, "Socates", ["1231", "Socate de plástico"]);
add(41, "Cajita", EL, "Enchufes e interruptores", ["UVECF-2", "Interruptor de pared doble"], ["UVECF-3", "Interruptor de pared triple"], ["UVECF-4", "Enchufe de pared"]);
add(42, "Cajita", EL, "Enchufes e interruptores", ["UVECF-7", "Enchufe con interruptor"], ["UVECF-8", "Enchufe doble con interruptor"], ["UVECF-10", "Enchufe con doble puerto de carga USB/tipo C"]);
add(43, "Cajita", EL, "Enchufes e interruptores", ["UVECF-11", "Enchufe doble con puerto de carga USB/tipo C"], ["ENC-4", "Portalámpara con interruptor de cadena y doble enchufe"]);
add(44, "Cajita", EL, "Enchufes e interruptores", ["UVECF-20", "Enchufe de pared con puerto de carga USB/tipo C"], ["UVECF-21", "Enchufe doble con puerto de carga USB/tipo C (gris)"]);
add(45, "Paquete", EL, "Enchufes e interruptores", ["ABS-003", "Enchufe 2T hembra metal"], ["ABS-008", "Enchufe 3T hembra tapón"]);
add(46, "Paquete", EL, "Enchufes e interruptores", ["ABS-001", "Enchufe 2P metal"], ["ABS-005", "Enchufe 2P tapón"]);
add(47, "Cajita", EL, "Enchufes e interruptores", ["ABS-111", "Interruptor triple"], ["ABS-120", "Tapa para interruptor"]);
add(48, "Cajita", EL, "Socates", ["SCT2020", "Socate negro"]);
add(48, "Paquete", EL, "Socates", ["ABS-102", "Socate negro con cable"]);
add(48, "Cajita", EL, "Enchufes e interruptores", ["1000", "Interruptor rectangular 2 switch"]);
add(49, "Cajita", EL, "Enchufes e interruptores", ["T302", "Enchufe 2T hembra tapón"], ["#303", "Enchufe 3T hembra metal"]);
add(50, "Paquete", EL, "Extensiones", ["YR282", "Extensión eléctrica 6 enchufes + 2 USB + tipo C"], ["YR283", "Extensión eléctrica con switch 3 enchufes + 2 USB + tipo C"]);
add(51, "Paquete", EL, "Extensiones", ["XW-P03", "Regleta 4 enchufes con apagador"], ["312", "Extensión 4 enchufes con apagador + 2 USB"], ["313", "Extensión 3 enchufes con apagador + 2 USB"]);
add(52, "Paquete", EL, "Cajetines", ["CA501", "Cajetín plástico cuadrado"]);
add(52, "Bulto", EL, "Cajetines", ["295", "Cajetín de hierro octagonal"], ["296", "Cajetín de hierro rectangular"]);
add(53, "Bulto", EL, "Cajetines", ["T298", "Tapa de hierro rectangular (bulto de 250)"], ["T298-100", "Tapa de hierro rectangular (bulto de 100)"]);
add(53, "Paquete", EL, "Cajetines", ["WJ-02-3", "Grapa para cables 22mm"]);
const ft = [6, 9, 12, 15, 18, 20, 25];
add(54, "Paquete", EL, "Extensiones", ...ft.slice(0, 6).map((m, i) => [`#${518 + i}`, `Extensión eléctrica blanca ${m} pies`]));
add(55, "Paquete", EL, "Extensiones", ...ft.map((m, i) => [`#N${518 + i}`, `Extensión eléctrica negra ${m} pies`]));

// Zona de foto para las páginas de tabla (coordenadas PDF, página 1440x810), medidas a mano.
const PAGE_RECT = {
  2: [918, 43, 1359, 559], 6: [660, 20, 1420, 500], 7: [36, 42, 660, 392], 8: [560, 20, 1430, 500], 9: [560, 20, 1430, 500],
  11: [600, 12, 1420, 540], 12: [20, 20, 1420, 520], 13: [20, 20, 700, 540], 14: [20, 20, 700, 540], 15: [420, 130, 980, 470],
  16: [40, 20, 1060, 470], 17: [20, 140, 500, 520], 18: [20, 120, 560, 440], 19: [380, 180, 980, 440], 20: [20, 40, 860, 420],
  21: [20, 20, 800, 440], 22: [20, 20, 450, 400], 23: [490, 120, 1400, 440], 24: [620, 20, 1420, 520], 25: [30, 20, 380, 430],
  26: [80, 30, 1420, 520], 27: [380, 280, 1430, 560], 28: [540, 20, 1420, 420], 29: [160, 20, 1430, 440], 30: [120, 30, 1340, 430],
  31: [320, 20, 1430, 420], 32: [20, 20, 460, 460], 33: [350, 80, 1430, 540], 54: [325, 27, 1404, 453], 55: [447, 27, 1420, 453],
};
// Cables: el rollo de cada color.
const CODE_RECT = {
  "CB8413-AM": [492, 250, 790, 500], "CB8413-AZ": [800, 250, 1100, 500], "CB8413-VE": [1100, 250, 1420, 500],
  "CB51414-NG": [660, 210, 935, 410], "CB51414-RJ": [964, 210, 1240, 410], "CB51414-AM": [523, 498, 797, 710], "CB51414-AZ": [827, 498, 1115, 710], "CB51414-VE": [1131, 498, 1420, 710],
  "CB51377-BL": [523, 164, 812, 380], "CB51377-NG": [842, 164, 1116, 380], "CB51377-RJ": [1131, 164, 1414, 380], "CB51377-AZ": [675, 453, 964, 670], "CB51377-VE": [979, 453, 1253, 670],
  "CB51370-BL": [508, 164, 797, 380], "CB51370-NG": [827, 164, 1116, 380], "CB51370-RJ": [1131, 164, 1404, 380], "CB51370-AM": [508, 468, 797, 685], "CB51370-AZ": [827, 468, 1116, 685], "CB51370-VE": [1131, 468, 1420, 685],
  "CB51263-NG": [508, 164, 797, 380], "CB51263-RJ": [827, 164, 1100, 380], "CB51263-VE": [1146, 164, 1420, 380], "CB51263-BL": [660, 468, 948, 700], "CB51263-AM": [1009, 468, 1298, 700],
  "CB51378-NG": [538, 164, 933, 395], "CB51378-RJ": [1003, 164, 1404, 395], "CB51378-BL": [781, 468, 1176, 700],
};

const doc = mupdf.Document.openDocument(fs.readFileSync(f), "application/pdf");
fs.mkdirSync(imgDir, { recursive: true });
const norm = s => s.replace(/\s+/g, "").toUpperCase();
const cache = {};
const items = P.map(([page, codigo, nombre, unidad, cat, sub], i) => {
  const id = `G-${String(i + 1).padStart(4, "0")}`;
  const pg = doc.loadPage(page - 1);
  const [, , W, H] = pg.getBounds();
  const lines = [];
  for (const b of JSON.parse(pg.toStructuredText().asJSON()).blocks)
    for (const l of b.lines || []) lines.push({ t: l.text, x0: l.bbox.x, y0: l.bbox.y, x1: l.bbox.x + l.bbox.w });
  const labels = lines.filter(l => /^CODIGO/i.test(l.t.trim()));
  const sell = lines.filter(l => /SE\s*VENDE/i.test(l.t));
  let rect = CODE_RECT[codigo] || PAGE_RECT[page];
  if (rect) {
    // medida a mano
  } else if (labels.length > 1 && labels.every(l => /^CODIGO:?\s*$/i.test(l.t.trim()) || /CODIGO:\s*\S/i.test(l.t))) {
    // recuadros: el recuadro es la franja de ancho W/n que contiene el código
    const n = labels.length, w = W / n;
    const hit = lines.find(l => norm(l.t).endsWith(norm(codigo))) || lines.find(l => norm(l.t).includes(norm(codigo)));
    const k = Math.min(n - 1, Math.floor(((hit.x0 + hit.x1) / 2) / w));
    const sv = sell.filter(l => l.x0 >= k * w - 5 && l.x0 < (k + 1) * w).map(l => l.y0);
    rect = [k * w + 6, 4, (k + 1) * w - 6, (sv.length ? Math.min(...sv) : H * 0.62) - 4];
  } else {
    // tabla: la foto más grande sobre la tabla (si no hay, toda la franja de fotos)
    const tops = lines.filter(l => /^(CODIGO|PRECIO)/i.test(l.t.trim())).map(l => l.y0);
    const top = (tops.length ? Math.min(...tops) : H * 0.75) - 8;
    const blocks = JSON.parse(pg.toStructuredText("preserve-images").asJSON()).blocks
      .filter(b => b.type === "image")
      .map(b => [Math.max(4, b.bbox.x), Math.max(4, b.bbox.y), Math.min(W - 4, b.bbox.x + b.bbox.w), Math.min(top, b.bbox.y + b.bbox.h)])
      .filter(r => r[2] - r[0] > 120 && r[3] - r[1] > 120 && r[2] - r[0] < W * 0.7);
    const area = r => (r[2] - r[0]) * (r[3] - r[1]);
    rect = blocks.sort((a, b) => area(b) - area(a))[0] || [4, 4, W - 4, top];
  }
  const key = page + ":" + rect.map(Math.round).join(",");
  if (!cache[key]) {
    cache[key] = `img/${id}.jpg`;
    const s = 520 / Math.max(rect[2] - rect[0], rect[3] - rect[1]);
    fs.writeFileSync(`${imgDir}/${id}.jpg`, draw(pg, rect, s).asJPEG(80));
  }
  return { id, nombre, codigo, cat, sub, unidad, img: cache[key], pagina: page };
});
fs.writeFileSync(outJson, JSON.stringify(items, null, 1));
console.log("G items:", items.length, "fotos:", Object.keys(cache).length);
