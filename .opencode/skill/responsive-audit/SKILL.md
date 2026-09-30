---
name: responsive-audit
description: Audita el responsive de GardenFood con Playwright MCP en viewports reales. Úsala cuando el diseño móvil se vea "como desktop", cuando algo se desborde en horizontal, cuando falte un breakpoint, o antes de mergear UI nueva. Cubre 360→1440, touch targets, texto ilegible y grids que no apilan.
---

# Auditoría responsive

El proyecto es Tailwind v4 con los breakpoints por defecto: `sm` 640, `md` 768,
`lg` 1024, `xl` 1280. `md` **no** significa "tablet con nav completa": a 768 px el
ancho útil son 704 px y 5 links de navegación + marca no entran.

## Herramientas

MCP `playwright` y `chrome-devtools` (configurados en `opencode.json`, proyecto).
Ambos exponen resize real de viewport, que es lo que hace falta: `maxWidth` en
`screenshot` solo escala la imagen y **no** dispara media queries.

```js
await tools.playwright.browser_resize({ width: 390, height: 844 });
```

El CLI de Playwright ya tiene Chromium en `~/.cache/ms-playwright`. Chrome de
Google requiere sudo; no hace falta para auditar.

## Anchos que hay que probar siempre

| Ancho | Qué representa |
|---|---|
| 360 | Android chico, el más apretado |
| 390 | iPhone 14/15, el caso por defecto |
| 430 | iPhone Pro Max |
| 640 | borde de `sm` |
| **768** | borde de `md` — el que más se rompe |
| 820 | iPad Air vertical |
| **1024** | borde de `lg` |
| 1440 | desktop de referencia |

Probar los bordes importa más que el medio: los bugs aparecen donde un grid
salta de 2 a 3 columnas o donde una nav aparece sin que quepan sus hijos.

## Qué medir

El desborde horizontal es el síntoma más visible, pero no el único. Correr este
script en cada ancho y en cada ruta:

```js
(() => {
  const vw = window.innerWidth, de = document.documentElement;
  const label = (el) => {
    const t = (el.innerText || '').trim().replace(/\s+/g, ' ').slice(0, 38);
    return el.tagName.toLowerCase() +
      (el.getAttribute('data-slot') ? '[' + el.getAttribute('data-slot') + ']' : '') +
      (t ? ' "' + t + '"' : '');
  };
  const o = { p: location.pathname, of: de.scrollWidth - vw, wide: [], small: [], tiny: [], cols: [] };

  document.querySelectorAll('*').forEach((el) => {
    const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || !r.width || !r.height) return;

    // 1. desborde horizontal, ignorando ancestros scrolleables a propósito
    if (r.right > vw + 1 || r.left < -1) {
      let p = el.parentElement, sk = false;
      while (p) {
        const pc = getComputedStyle(p);
        if (pc.overflowX === 'auto' || pc.overflowX === 'scroll' || pc.overflow === 'hidden') { sk = true; break; }
        p = p.parentElement;
      }
      if (!sk) o.wide.push({ el: label(el), w: Math.round(r.width), right: Math.round(r.right) });
    }

    // 2. targets táctiles chicos (guía: 44 px, mínimo tolerable 40×32)
    if (el.matches('a,button,[role=tab],[role=button],input,select,textarea') &&
        (r.width < 40 || r.height < 32)) o.small.push({ el: label(el), w: Math.round(r.width), h: Math.round(r.height) });

    // 3. texto ilegible en teléfono
    const fs = parseFloat(cs.fontSize);
    if (el.children.length === 0 && (el.innerText || '').trim() && fs < 11) o.tiny.push({ el: label(el), fs });

    // 4. grid de 3+ columnas que no apila en móvil
    if (cs.display === 'grid' || cs.display === 'inline-grid') {
      const c = cs.gridTemplateColumns.split(' ').filter(Boolean).length;
      if (c >= 3 && r.width > 0 && (el.innerText || '').trim()) {
        o.cols.push({ el: label(el), c, w: Math.round(r.width), per: Math.round(r.width / c) });
      }
    }
  });
  return JSON.stringify({
    p: o.p, overflowPx: o.of,
    nWide: o.wide.length, wide: o.wide.slice(0, 6),
    nSmall: o.small.length, small: o.small.slice(0, 6),
    tiny: o.tiny.slice(0, 5), cols: o.cols.slice(0, 5),
  });
})()
```

## Rutas a cubrir

Públicas: `/`, `/especies/<slug>` (las 9 pestañas), `/explorar`, `/pricing`,
`/login`, `/registro`, `/legal/*`.

Privadas (hacen falta credenciales): `/huerto` + sus pestañas, `/perfil` (incluye
el quiz de suelo), `/calendario`, `/cosechas`, `/recomendadas`, `/calculadoras`,
`/admin/*`.

## Reglas que se han incumplido en este repo

1. **Una nav de links completa necesita `lg`, no `md`.** El error real de la
   rama `fix/post-reunion-suelo-riego-mapa`: `UserNav` con 5 links + Admin +
   Perfil + salir visible desde `md:flex` (768 px). A 768 y 820 el nav se salía,
   Perfil y "salir" quedaban cortados y la página scrolleaba en horizontal. Al
   moverlo a `lg:flex` hay que **subir también la `BottomNav` de `md:hidden` a
   `lg:hidden`**, o el rango 768–1024 se queda sin navegación.

2. **Unidad de la barra inferior.** `BottomNav` reparte 5 destinos (6 con admin)
   en `grid-cols-5/6`. A 390 px son 75 px (63 px con admin): la etiqueta
   "Biblioteca" entra justa. No bajar de `text-[11px]`.

3. **Pestañas con 9 entradas.** Se hacen carrusel: `overflow-x-auto`,
   `scrollbar-none` (utility propia en `app/globals.css`) y degradados
   `pointer-events-none` en los bordes como pista de que hay más. Cada
   `TabsTrigger` queda en ~23 px de alto: es la densidad de un control de
   escritorio en un teléfono, y conviene subirlo a `min-h-9` si el jefe se queja
   de que "no se puede tocar".

4. **Recharts no es mobile-first.** `interval={0` fuerza todas las etiquetas del
   eje X. A 390 px hay que `interval="preserveStartEnd"` + `minTickGap`, y quitar
   el `label` rotado del eje Y: roba ~100 px de ancho útil.

5. **Un `min-w-[Npx]` ancho necesita su `overflow-x-auto`.** El Gantt de
   Fenología usa `min-w-[640px]` dentro de `CardContent overflow-x-auto`: es
   intencional y está bien, pero en móvil es una tabla de escritorio scrolleable.
   Si molesta, la alternativa es una vista de lista por macrozona bajo `sm`.

## Reglas del harness

`proxy.ts` manda `Content-Security-Policy frame-ancestors 'none'`, así que **no se
puede envolver la app en un iframe para medir 390 px** sin tocar el CSP. Con
Playwright no hace falta: se cambia el viewport de verdad. Si algún día se usa
el iframe, el relaxation del CSP tiene que ser `dev`-only y revertirse antes de
commitear.

## Antes de dar por buena una UI

`pnpm lint && pnpm typecheck && pnpm test` en verde, y las capturas a 360 y 768
miradas con ojos, no solo los números. El desbordamiento real se ve en la
captura; el texto chico y los targets chicos solo aparecen midiendo.
