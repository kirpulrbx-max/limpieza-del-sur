# Catálogo web — Productos de Limpieza del Sur C.A.

Página estática (HTML + CSS + JS, sin servidor). Se abre con `index.html` o se sube tal cual a Netlify, GitHub Pages, Vercel o cualquier hosting.

## Archivos
- `config.js` — **edita aquí** los vendedores (WhatsApp) y datos de la empresa.
- `productos.js` — lista de productos (1.204, sin los agotados) extraída de los catálogos PDF: nombre, código, foto y presentación.
- `img/` — fotos de los productos.
- `index.html`, `styles.css`, `app.js` — la página.

## Agregar o corregir un producto
Cada producto en `productos.js` es una línea como:

```js
{"id":"X-0001","n":"Nombre del producto","c":"COD123","cat":"Nombre del catálogo","img":"img/X-0001.jpg"},
```

Campos opcionales: `"sub"` (categoría), `"p"` (presentación), `"b"` (contenido del bulto), `"u":["Pieza","Bulto"]` (presentaciones que se pueden pedir).

## Cómo funciona el pedido
El cliente agrega productos al carrito, llena sus datos, escoge el vendedor, y al presionar **Enviar pedido por WhatsApp** se abre el chat del vendedor con el pedido ya escrito. No se muestran precios.
