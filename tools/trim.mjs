import * as mupdf from "mupdf";

export function draw(page, r, s) {
  const m = mupdf.Matrix.concat(mupdf.Matrix.translate(-r[0], -r[1]), mupdf.Matrix.scale(s, s));
  const pix = new mupdf.Pixmap(mupdf.ColorSpace.DeviceRGB, [0, 0, Math.round((r[2] - r[0]) * s), Math.round((r[3] - r[1]) * s)], false);
  pix.clear(255);
  const dev = new mupdf.DrawDevice(m, pix); page.run(dev, mupdf.Matrix.identity); dev.close();
  return pix;
}

// pixel that belongs to a frame or margin: light (white / paper) or the frame colour (blue or green)
function isBorder(d, i) {
  const r = d[i], g = d[i + 1], b = d[i + 2];
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  if (mn > 205 && mx - mn < 35) return true;
  if (b > r + 50 && b > g + 15) return true;      // azul
  if (g > r + 30 && g >= b - 10) return true;     // verde
  return false;
}

// Renders rect `r` of `page`, trimming frame lines and empty margins on every side.
export function renderTrimmed(page, r, maxSide) {
  const s0 = 300 / Math.max(r[2] - r[0], r[3] - r[1]);
  const pix = draw(page, r, s0);
  const w = pix.getWidth(), h = pix.getHeight(), n = pix.getNumberOfComponents(), st = pix.getStride();
  const d = pix.getPixels();
  const row = y => { let k = 0; for (let x = 0; x < w; x++) k += isBorder(d, y * st + x * n); return k / w; };
  const col = x => { let k = 0; for (let y = 0; y < h; y++) k += isBorder(d, y * st + x * n); return k / h; };
  const TH = 0.93, MAXF = 0.2;
  // longest run of frame-blue pixels along a line, as a fraction of its length
  const isBlue = i => d[i + 2] > d[i] + 50 && d[i + 2] > d[i + 1] + 15;
  const runRow = y => { let best = 0, cur = 0; for (let x = 0; x < w; x++) { cur = isBlue(y * st + x * n) ? cur + 1 : 0; if (cur > best) best = cur; } return best / w; };
  const runCol = x => { let best = 0, cur = 0; for (let y = 0; y < h; y++) { cur = isBlue(y * st + x * n) ? cur + 1 : 0; if (cur > best) best = cur; } return best / h; };
  // start past the innermost long blue line near each edge (pieces of the frame)
  const lastLine = (len, fn) => { let k = 0; for (let i = 0; i < len * 0.08; i++) if (fn(i) > 0.3) k = i + 1; return k; };
  let t = lastLine(h, runRow), b = lastLine(h, y => runRow(h - 1 - y)), l = lastLine(w, runCol), rr = lastLine(w, x => runCol(w - 1 - x));
  while (t < h * MAXF && row(t) >= TH) t++;
  while (b < h * MAXF && row(h - 1 - b) >= TH) b++;
  while (l < w * MAXF && col(l) >= TH) l++;
  while (rr < w * MAXF && col(w - 1 - rr) >= TH) rr++;
  // extra margin to clear rounded corners of the frame
  const ex = Math.round(Math.min(w, h) * 0.03);
  if (t) t += ex; if (b) b += ex; if (l) l += ex; if (rr) rr += ex;
  const nr = [r[0] + l / s0, r[1] + t / s0, r[2] - rr / s0, r[3] - b / s0];
  const s = maxSide / Math.max(nr[2] - nr[0], nr[3] - nr[1]);
  return draw(page, nr, s);
}
