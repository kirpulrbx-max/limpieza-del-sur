# Catálogo web — Productos de Limpieza del Sur C.A.

Página estática (HTML + CSS + JS, sin servidor). Se abre con `index.html` o se sube tal cual a Netlify, GitHub Pages, Vercel o cualquier hosting.

## Archivos
- `config.js` — **edita aquí** los vendedores (WhatsApp) y datos de la empresa.
- `productos.js` — lista de productos extraída de los catálogos PDF: nombre, código, foto, presentación y precio.
- `img/` — fotos de los productos.
- `index.html`, `styles.css`, `app.js` — la página.
- `tools/` — scripts para extraer productos de los catálogos PDF (ver abajo).

## Agregar o corregir un producto
Cada producto en `productos.js` es una línea como:

```js
{"id":"X-0001","n":"Nombre del producto","c":"COD123","cat":"Nombre del catálogo","img":"img/X-0001.jpg"},
```

Campos opcionales: `"sub"` (categoría), `"p"` (presentación), `"b"` (contenido del bulto), `"u":["Pieza","Bulto"]` (presentaciones que se pueden pedir), `"pr":6.5` (precio en $).

## Precios
Los productos de los catálogos **Davey** (Hogar, Variedades y Ferretería) llevan precio:
**(precio en ¥ ÷ 6) × 1,20**. En el PDF el punto separa los miles ("¥: 1.050" = 1050 yuanes) y la coma es decimal. El precio es por la presentación del catálogo (ej. "por paquete de 12 piezas").
Los productos de la lista Excel de Xavier llevan el precio del Excel + 20 %; los de Navidad conservan el precio impreso en el PDF. Estas reglas están en `tools/precios.json`.
Los productos **Kingsbright** del catálogo Corpexca usan la misma regla con el precio por unidad, salvo los que están en el Excel de Xavier, que llevan el precio del Excel + 20 %.
Los demás productos se muestran sin precio y el vendedor lo confirma.

## Actualizar con catálogos nuevos
Requiere Node.js. Dentro de `tools/`:

```bash
npm install
node davey.mjs catalogo-hogar.pdf A out/A.json out/img
node davey.mjs catalogo-variedades.pdf B out/B.json out/img
node canaima.mjs catalogo-iluminacion.pdf out/G.json out/img
node corpexca.mjs catalogo-corpexca.pdf out/K.json out/img
node merge.mjs
node iluminacion.mjs
```

`davey.mjs` lee código, nombre, precio y foto de cada producto y descarta los agotados.
`canaima.mjs` tiene la lista de productos de iluminación escrita a mano (sus páginas no siguen un formato fijo).
`corpexca.mjs` extrae los productos Kingsbright disponibles y sus fotos; `merge.mjs` reemplaza y agrega productos, y copia las fotos.
`iluminacion.mjs` quita los bombillos que no son Kingsbright ni Amanerluz y ordena Iluminación: primero bombillos Amanerluz, luego Kingsbright, luego reflectores y después el resto.

## Publicar cambios
Después de cambiar `productos.js`, `app.js`, `styles.css` o `config.js`, sube el número `?v=` de esos archivos en `index.html`. Así los teléfonos descargan la versión nueva en vez de usar la guardada.

## Cómo funciona el pedido
El cliente agrega productos al carrito, llena sus datos, escoge el vendedor, y al presionar **Enviar pedido por WhatsApp** se abre el chat del vendedor con el pedido ya escrito, con el total estimado de los productos que tienen precio.
