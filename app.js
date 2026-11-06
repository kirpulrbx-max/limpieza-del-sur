(() => {
  const C = window.CONFIG, P = window.PRODUCTOS;
  const byId = Object.fromEntries(P.map(p => [p.id, p]));
  const $ = s => document.querySelector(s);
  const PAGE = 24;
  const ALL = "Todos";
  const state = { q: "", cat: ALL, sub: ALL, page: 1 };
  const KEY = "lds-pedido";
  let cart = load();

  function load() { try { return JSON.parse(localStorage.getItem(KEY)) || []; } catch { return []; } }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(cart)); } catch {} }
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const norm = s => String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
  const units = p => p.u && p.u.length ? p.u : ["Unidad", "Docena", "Bulto"];
  P.forEach(p => { p._s = norm(`${p.n} ${p.c} ${p.sub || ""} ${p.cat}`); });

  // nombre corto e ícono de cada catálogo
  const CATS = {
    "Navidad": ["Navidad", "🎄"],
    "Iluminación y pilas": ["Iluminación", "💡"],
    "Hogar, cocina y decoración": ["Hogar", "🏠"],
    "Repostería": ["Repostería", "🧁"],
    "Tecnología": ["Tecnología", "🎧"],
    "Variedades, mascotas y juguetes": ["Variedades", "🧸"],
    "Ferretería, electricidad y plomería": ["Ferretería", "🔧"],
  };
  const short = c => (CATS[c] || [c])[0];

  const shuffle = a => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };

  // ---- Categorías ----
  const order = Object.keys(CATS);
  const cats = [...new Set(P.map(p => p.cat))].sort((a, b) => (order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99));
  function renderTree() {
    const item = (c, icon, n, subs) => {
      const open = subs.length && state.cat === c;
      return `<li class="${open ? "open" : ""}">
        <button class="${state.cat === c && state.sub === ALL ? "on" : ""}" data-cat="${esc(c)}"><span class="ico">${icon}</span>${esc(c === ALL ? "Todos los productos" : short(c))}<span class="n">${n}</span>${subs.length ? `<span class="chev">▾</span>` : ""}</button>
        ${subs.length ? `<ul>${subs.map(s => `<li><button class="${state.cat === c && state.sub === s ? "on" : ""}" data-cat="${esc(c)}" data-sub="${esc(s)}">${esc(s)}</button></li>`).join("")}</ul>` : ""}
      </li>`;
    };
    $("#tree").innerHTML = item(ALL, "🛍️", P.length, []) +
      cats.map(c => item(c, (CATS[c] || [, "•"])[1], P.filter(p => p.cat === c).length, [...new Set(P.filter(p => p.cat === c && p.sub).map(p => p.sub))])).join("");
  }
  $("#tree").addEventListener("click", e => {
    const b = e.target.closest("[data-cat]"); if (!b) return;
    state.cat = b.dataset.cat; state.sub = b.dataset.sub || ALL; state.page = 1;
    renderTree(); renderGrid();
  });

  let t;
  $("#q").addEventListener("input", e => { clearTimeout(t); t = setTimeout(() => { state.q = e.target.value; state.page = 1; renderGrid(); }, 150); });
  $("#searchForm").addEventListener("submit", e => { e.preventDefault(); state.q = $("#q").value; state.page = 1; renderGrid(); $("#catalogo").scrollIntoView({ behavior: "smooth" }); });
  $("#focusSearch").addEventListener("click", () => { $("#catalogo").scrollIntoView({ behavior: "smooth" }); setTimeout(() => $("#q").focus(), 350); });
  $("#brand").addEventListener("click", () => { state.cat = ALL; state.sub = ALL; state.q = ""; $("#q").value = ""; state.page = 1; renderTree(); renderGrid(); });

  function filtered() {
    const words = norm(state.q).split(/\s+/).filter(Boolean);
    return P.filter(p =>
      (state.cat === ALL || p.cat === state.cat) &&
      (state.sub === ALL || p.sub === state.sub) &&
      words.every(w => p._s.includes(w)));
  }

  // ---- Tarjetas ----
  function card(p) {
    const sub = p.p || (p.b ? `Bulto: ${p.b}` : "");
    return `<article class="card" data-id="${p.id}">
      <button class="ph" data-zoom aria-label="Ver foto de ${esc(p.n)}">
        <img src="${p.img}" alt="${esc(p.n)}" loading="lazy" decoding="async">
        <span class="tag">${esc(p.sub || short(p.cat))}</span>
      </button>
      <div class="info">
        <h3>${esc(p.n)}</h3>
        ${p.c ? `<span class="code">${esc(p.c)}</span>` : ""}
      </div>
      <div class="sub">${sub ? `<span class="dot">●</span> ${esc(sub)}` : ""}</div>
      <div class="acts">
        <button class="btn ghost sm" data-add>Agregar</button>
        <button class="btn dark sm" data-buy>Pedir ya</button>
      </div>
    </article>`;
  }

  function pager(total) {
    const pages = Math.ceil(total / PAGE), cur = state.page;
    if (pages <= 1) { $("#pager").innerHTML = ""; return; }
    const nums = [];
    for (let i = 1; i <= pages; i++) {
      if (i === 1 || i === pages || Math.abs(i - cur) <= 1 || (cur <= 3 && i <= 4) || (cur >= pages - 2 && i >= pages - 3)) nums.push(i);
      else if (nums[nums.length - 1] !== "…") nums.push("…");
    }
    $("#pager").innerHTML = `<button data-page="${cur - 1}" ${cur === 1 ? "disabled" : ""}>← Anterior</button>
      <div class="nums">${nums.map(n => n === "…" ? `<span class="gap">…</span>` : `<button data-page="${n}" class="${n === cur ? "on" : ""}">${n}</button>`).join("")}</div>
      <button data-page="${cur + 1}" ${cur === pages ? "disabled" : ""}>Siguiente →</button>`;
  }
  $("#pager").addEventListener("click", e => {
    const b = e.target.closest("[data-page]"); if (!b || b.disabled) return;
    state.page = +b.dataset.page; renderGrid();
    $("#catalogo").scrollIntoView({ behavior: "smooth" });
  });

  function renderGrid() {
    const list = filtered();
    const from = (state.page - 1) * PAGE;
    $("#grid").innerHTML = list.slice(from, from + PAGE).map(card).join("");
    $("#resultCount").textContent = list.length ? `Mostrando ${from + 1}–${Math.min(from + PAGE, list.length)} de ${list.length} productos` : "";
    $("#empty").hidden = list.length > 0;
    pager(list.length);
  }

  // ---- Recomendados ----
  $("#rail").innerHTML = shuffle(P).slice(0, 12).map(card).join("");
  const step = () => $("#rail").firstElementChild.offsetWidth + 18;
  $("#recPrev").addEventListener("click", () => $("#rail").scrollBy({ left: -step(), behavior: "smooth" }));
  $("#recNext").addEventListener("click", () => $("#rail").scrollBy({ left: step(), behavior: "smooth" }));

  function onCard(e) {
    const el = e.target.closest(".card"); if (!el) return;
    const p = byId[el.dataset.id];
    if (e.target.closest("[data-zoom]")) return openZoom(p);
    const add = e.target.closest("[data-add]");
    if (add) {
      addToCart(p.id, units(p)[0], 1);
      add.textContent = "✓ Agregado"; add.classList.add("ok");
      setTimeout(() => { add.textContent = "Agregar"; add.classList.remove("ok"); }, 1200);
    }
    if (e.target.closest("[data-buy]")) { addToCart(p.id, units(p)[0], 1); openCart(); }
  }
  $("#grid").addEventListener("click", onCard);
  $("#rail").addEventListener("click", onCard);

  // ---- Carrito ----
  function addToCart(id, unit, qty) {
    const l = cart.find(x => x.id === id && x.unit === unit);
    if (l) l.qty += qty; else cart.push({ id, unit, qty });
    save(); renderCart();
    const b = $("#openCart"); b.classList.remove("bump"); void b.offsetWidth; b.classList.add("bump");
    toast(`${byId[id].n} agregado al pedido`);
  }
  function renderCart() {
    cart = cart.filter(l => byId[l.id]);
    const n = cart.reduce((s, l) => s + l.qty, 0);
    $("#cartCount").textContent = n;
    $("#emptyCart").hidden = cart.length > 0;
    $("#orderForm").hidden = cart.length === 0;
    $("#lines").innerHTML = cart.map((l, i) => {
      const p = byId[l.id];
      return `<li class="line" data-i="${i}">
        <img src="${p.img}" alt="">
        <div><b>${esc(p.n)}</b>${p.c ? `<span class="meta">Cód: ${esc(p.c)}</span>` : ""}
          <div class="ctl">
            <div class="qty"><button type="button" data-cstep="-1" aria-label="Menos">−</button><input type="number" min="1" value="${l.qty}" data-cqty aria-label="Cantidad"><button type="button" data-cstep="1" aria-label="Más">+</button></div>
            <select class="unit" data-cunit aria-label="Presentación">${units(p).map(u => `<option ${u === l.unit ? "selected" : ""}>${esc(u)}</option>`).join("")}</select>
          </div>
        </div>
        <button class="rm" data-rm aria-label="Quitar">×</button>
      </li>`;
    }).join("");
  }
  $("#lines").addEventListener("click", e => {
    const li = e.target.closest(".line"); if (!li) return;
    const l = cart[+li.dataset.i];
    if (e.target.closest("[data-rm]")) cart.splice(+li.dataset.i, 1);
    else if (e.target.closest("[data-cstep]")) l.qty = Math.max(1, l.qty + +e.target.closest("[data-cstep]").dataset.cstep);
    else return;
    save(); renderCart();
  });
  $("#lines").addEventListener("change", e => {
    const li = e.target.closest(".line"); if (!li) return;
    const l = cart[+li.dataset.i];
    if (e.target.matches("[data-cqty]")) l.qty = Math.max(1, parseInt(e.target.value) || 1);
    if (e.target.matches("[data-cunit]")) l.unit = e.target.value;
    save(); renderCart();
  });
  $("#clearCart").addEventListener("click", () => { if (confirm("¿Vaciar todo el pedido?")) { cart = []; save(); renderCart(); } });

  const drawer = $("#drawer"), scrim = $("#scrim");
  function openCart() { drawer.classList.add("open"); drawer.setAttribute("aria-hidden", "false"); scrim.hidden = false; document.body.style.overflow = "hidden"; }
  function closeCart() { drawer.classList.remove("open"); drawer.setAttribute("aria-hidden", "true"); scrim.hidden = true; document.body.style.overflow = ""; }
  $("#openCart").addEventListener("click", openCart);
  $("#closeCart").addEventListener("click", closeCart);
  scrim.addEventListener("click", closeCart);

  // ---- Formulario y WhatsApp ----
  const radios = (el, name, items) => {
    $(el).innerHTML = items.map((it, i) => {
      const o = typeof it === "string" ? { nombre: it } : it;
      return `<label class="opt"><input type="radio" name="${name}" value="${i}" ${i === 0 ? "checked" : ""}><span>${esc(o.nombre)}${o.detalle ? `<small>${esc(o.detalle)}</small>` : ""}</span></label>`;
    }).join("");
  };
  radios("#vendedores", "vendedor", C.vendedores);
  if (C.vendedores.length === 1) $("#vendedores").previousElementSibling.hidden = $("#vendedores").hidden = true;

  const FORM_KEY = "lds-cliente";
  const form = $("#orderForm");
  try { const d = JSON.parse(localStorage.getItem(FORM_KEY)) || {}; for (const k of ["nombre", "doc", "tel", "dir"]) if (d[k]) form.elements[k].value = d[k]; } catch {}

  form.addEventListener("submit", e => {
    e.preventDefault();
    const f = form.elements, err = $("#err");
    const vend = form.querySelector("[name=vendedor]:checked");
    const missing = [];
    if (!f.nombre.value.trim()) missing.push("tu nombre");
    if (!f.tel.value.trim()) missing.push("tu teléfono");
    if (!vend) missing.push("el vendedor");
    if (missing.length) { err.textContent = `Falta: ${missing.join(", ")}.`; err.hidden = false; return; }
    err.hidden = true;
    try { localStorage.setItem(FORM_KEY, JSON.stringify({ nombre: f.nombre.value, doc: f.doc.value, tel: f.tel.value, dir: f.dir.value })); } catch {}

    const v = C.vendedores[+vend.value];
    const items = cart.map((l, i) => {
      const p = byId[l.id];
      return `${i + 1}. ${p.n}${p.c ? `\n    Cód: ${p.c}` : ""}\n    Cant: ${l.qty} ${l.unit}`;
    });
    const msg = [
      `*NUEVO PEDIDO — ${C.empresa}*`,
      ``,
      `*Cliente:* ${f.nombre.value.trim()}`,
      f.doc.value.trim() ? `*Cédula/RIF:* ${f.doc.value.trim()}` : null,
      `*Teléfono:* ${f.tel.value.trim()}`,
      f.dir.value.trim() ? `*Dirección:* ${f.dir.value.trim()}` : null,
      ``,
      `*Productos (${cart.length}):*`,
      ...items,
      f.notas.value.trim() ? `\n*Notas:* ${f.notas.value.trim()}` : null,
      ``,
      `Por favor confirmar disponibilidad y precio. ¡Gracias!`,
    ].filter(x => x !== null).join("\n");
    window.open(`https://wa.me/${v.whatsapp.replace(/\D/g, "")}?text=${encodeURIComponent(msg)}`, "_blank", "noopener");
    toast(`Abriendo WhatsApp de ${v.nombre}…`);
  });

  // ---- Zoom y aviso ----
  function openZoom(p) {
    $("#zoomImg").src = p.img; $("#zoomImg").alt = p.n;
    $("#zoomCap").textContent = p.c ? `${p.n} — Cód: ${p.c}` : p.n;
    $("#zoom").hidden = false;
  }
  $("#zoom").addEventListener("click", () => { $("#zoom").hidden = true; });
  document.addEventListener("keydown", e => { if (e.key === "Escape") { $("#zoom").hidden = true; closeCart(); } });
  let tt;
  function toast(s) { const el = $("#toast"); el.textContent = s; el.classList.add("show"); clearTimeout(tt); tt = setTimeout(() => el.classList.remove("show"), 1800); }

  // ---- Pie ----
  $("#ctaCart").addEventListener("click", openCart);
  $("#footName").textContent = C.empresa;
  $("#footRif").textContent = `RIF ${C.rif}`;
  $("#footCats").innerHTML = cats.map(c => `<li><a href="#catalogo" data-fcat="${esc(c)}">${esc(short(c))}</a></li>`).join("");
  $("#footCats").addEventListener("click", e => { const a = e.target.closest("[data-fcat]"); if (!a) return; state.cat = a.dataset.fcat; state.sub = ALL; state.page = 1; renderTree(); renderGrid(); });
  $("#footVend").innerHTML = C.vendedores.map(v => `<li><a href="https://wa.me/${v.whatsapp.replace(/\D/g, "")}" target="_blank" rel="noopener">${esc(v.nombre)}</a></li>`).join("");
  $("#copy").textContent = `© ${new Date().getFullYear()} ${C.empresa}`;

  renderTree(); renderGrid(); renderCart();
})();
