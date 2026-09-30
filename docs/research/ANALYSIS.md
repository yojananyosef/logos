# Análisis de Logos Web App — Base para el clon 1:1 en Flutter

Fecha: 2026-09-29
Método: scraping automatizado con Playwright sobre `app.logos.com` + extracción de los 1893 design tokens CSS que la app expone en `document.documentElement`.

Capturas y volcados de texto en `docs/research/`.

---

## 1. Acceso

- El login con cuenta de usuario falló en 3 intentos con un error de servidor:
  *"Lo sentimos, se ha producido un error... puede que necesite verifique su correo electrónico."*
  Es un problema **del lado de la cuenta**, no del scraping. No se puede resolver sin que el
  titular verifique el correo o use otro acceso.
- **Alternativa que sí funcionó:** los URLs con token `zzls=` que ya traía el encargo abren la
  app directamente en modo invitado (free tier). Con eso se pudo recorrer **la app real completa**.

Todo el análisis siguiente proviene de la app real en modo invitado.

---

## 2. Arquitectura de la interfaz

La app es un **workspace de paneles con pestañas**, no un simple sitio:

```
┌──────────────────────────────────────────────────────────────────────┐
│ [logo] [Pasaje o tema .........] │  Panel de Control │ Create free… │ ← top bar
├──────────┬───────────────────────────────────────────────────────────┤
│ ⌂ Panel de Control          │                                       │
│ ▤ Biblioteca                │   ┌─── RVR60 ──┬─ Buscar ─┬ LBLA ─┐   │ ← tab strip
│ 🔍 Buscar                  │   ├────────────┴──────────┴────────┤   │
│ ✝ Biblia                   │   │  Inicio|Búsqueda|Notas|        │   │ ← toolbar de pestaña
│ ◌ Asistente de estudio     │   │  Formato|Vista|Compartir        │   │
│ ✓ Enciclopedia bíblica     │   ├─────────────────────────────────┤   │
│ ⊘ Guías de Estudio         │   │ Contenido|Historia|Artículo|     │   │ ← sub-toolbar
│ ✎ Notas                    │   │ Conjunto de enlaces             │   │
│ ⊞ Herramientas             │   ├─────────────────────────────────┤   │
│                            │   │                                 │   │
│ Acciones Rápidas           │   │      contenido del recurso      │   │
│  ▸ Abrir un comentario     │   │                                 │   │
│  ▸ Abrir una Biblia…       │   │                                 │   │
│  ▸ Comparar versiones…    │   │                                 │   │
│  ▸ Abrir un diccionario…   │   │                                 │   │
│  ▸ Abrir el devocional…    │   │                                 │   │
│                            │   │                                 │   │
│ ? Centro de ayuda         │   │                                 │   │
│ ⊟ Entornos                │   │                                 │   │
│ ⊠ Cerrar todos los paneles│   │                                 │   │
├──────────┴───────────────────────────────────────────────────────────┤
│ ⋮  Ingresar                                                    ‹    │ ← bottom bar + colapsar
└──────────────────────────────────────────────────────────────────────┘
```

Piezas clave:

| Pieza | Descripción |
|---|---|
| **Rail de iconos** (48px) | Logo, grid, y el campo `Pasaje o tema` (búsqueda global) |
| **Sidebar** (~207px) | Navegación principal + Acciones Rápidas + pie con ayuda/Entornos/Cerrar paneles |
| **Botón colapsar** `‹` | Plegar el sidebar a solo iconos |
| **Tab strip** | Pestañas de recurso: nombre + badge de accesibilidad (`A`) + cerrar (`×`) |
| **Toolbar de pestaña** | Inicio · Búsqueda · Notas · Formato · Vista · Compartir · Más |
| **Sub-toolbar** | Contenido · Historia · Artículo · Conjunto de enlaces · Ideas · Información del libro |
| **Header de recurso** | `The Gospel according to John › Chapter 1` + `×` |
| **Panel derecho** | Overlay contextual: Contenido / Historia / Conjunto de enlaces |

Opciones del panel **Vista** (confirmadas):
`Vista por páginas` · `Barra localizadora` · `Aumentar/Disminuir: 100%` · `Pantalla completa`

---

## 3. Las 9 pantallas

| # | Pantalla | Ruta | Contenido |
|---|---|---|---|
| 1 | **Panel de Control** | `/` | Banner promo azul, sección `EXPLORAR` con tarjetas, `De su biblioteca` |
| 2 | **Biblioteca** | `?activeMenu=library` | Buscador + filtros `Suyos / Tienda / por Título`, lista de recursos con portada |
| 3 | **Buscar** | `/search` | Tabs `Todo/Biblia/Libros`, panel de sintaxis, Operadores básicos, Ayuda adicional |
| 4 | **Biblia** | `/books/LLS:1.0.x` | Lector con texto, notas al pie, referencias cruzadas azules |
| 5 | **Asistente de estudio** | `/tools/study-assistant` | Chat de IA con citas |
| 6 | **Enciclopedia bíblica** | `/tools/factbook` | Artículos enciclopédicos |
| 7 | **Guías de Estudio** | `?activeMenu=guides` | Guías guiadas |
| 8 | **Notas** | `/tools/notes` | `sort=modifiedDesc&viewMode=full` |
| 9 | **Herramientas** | `?activeMenu=tools` | Atlas focalizado, Comparación de versiones, Cursos, Documentos, Enciclopedia, Información, Recursos gráficos |

### Panel de Control (home)
- Banner: `#154ac9`, texto blanco, botón blanco `Ver descuentos`, `✕` a la derecha.
- `EXPLORAR`: masonry de tarjetas. Tipos observados:
  - *Anuncio* — navy `#030b60` → gradiente, título grande, badge `AGO. 2026`, CTA azul.
  - *Novedades* — imagen de app arriba, título bold, cuerpo 3 líneas, autor al pie.
  - *Pre-order* — badge `Pre-orden`, portada de libro, título bold, descripción, botón azul `Pre-orden ahora`.
  - *Banner de servicio* — azul, imagen a la derecha.
- `De su biblioteca` — tarjeta ancha con portada y descripción del recurso.

### Buscar
Tabs `Todo | Biblia | Libros`. Si no hay consulta, muestra el panel de ayuda:
- Ejemplos de sintaxis: `amor al prójimo`, `amor O prójimo`, `"hijo del Hombre"`, `Crist*`, `s?n`, `Biblia:"Jn 3:16"`.
- `Operadores básicos`: `solo una palabra u otra`, `Ambas palabras`, `Una palabra, pero no la otra`, `antes que otra`, `después de otra`, `cerca de otra`.
- `Buscar palabras clave`, `Ayuda adicional` (Manual de Ayuda, Wiki, Grupo de búsqueda).

### Herramientas
Menú: `Atlas focalizado`, `Comparación de versiones`, `Cursos`, `Documentos`, `Enciclopedia bíblica`, `Información`, `Recursos gráficos`.

---

## 4. Sistema de diseño (extraído de los tokens reales)

Fuente: `docs/research/design-tokens.json` (1893 variables `--bible-study-theme-*`).

### Color
| Rol | Hex |
|---|---|
| Marca / primario | `#154ac9` |
| Navy profundo (alto contraste) | `#030b60` |
| Link | `#1e6afe` |
| Link hover / focus ring | `#4797ff` |
| Azul claro (fondos) | `#e9f5ff` |
| Azul pill claro | `#8bc5ff` |
| Texto principal | `#333333` |
| Texto secundario | `#515d72` |
| Texto terciario / iconos | `#63728c` · `#888888` |
| Texto deshabilitado | `#c7cfdc` |
| Borde | `#e7e7e7` |
| Borde fuerte | `#cccccc` |
| Fondo toolbar / hover item | `#eeeeee` / `#f4f4f4` |
| Fondo sidebar / contenido | `#ffffff` |
| Icono tab bar | `#63728c` |
| Alerta fondo / icono | `#fff4d5` / `#dba910` |
| Error | `#cc3333` |
| Éxito | `#55b155` / `#dbf3db` |
| Mapa bíblico | `#ff6600` |
| Fondo tile inactivo | `#eeeeee` · icono `#cccccc` |

### Tipografía
- Familia: **Source Sans Pro** (fallback `sans-serif`)
- Base: `16px`, weight `400`
- Botón activo: borde inferior `2px` de `#154ac9`, fondo `#f4f4f4`

### Métricas
- Sidebar: `#ffffff`, borde derecho `1px #e7e7e7`
- Barra de icono de tab: icono `#63728c`, hover/selected bg `#f4f4f4`
- Card: token `--bible-study-theme-card-*` (86 vars)
- Toast: 88 vars · Sermon: 128 vars · Button: 548 vars

---

## 5. Responsive — el hallazgo importante

Se capturó la app real en 4 viewports (`rw-390-mobile.png`, `rw-768-tablet.png`, `rw-1280-laptop.png`).

**La app original de Logos NO es responsive.** En 390px:
- El sidebar conserva ~207px fijos.
- El contenido se sale del viewport → **desbordamiento horizontal**.
- El banner promo queda cortado ("...con" / "hasta 50% de descuento" truncado).
- La tarjeta V53 queda cortada a la derecha.
- No hay drawer móvil, ni bottom nav, ni breakpoint alguno.

Esto es una oportunidad, no un obstacle: el clon debe ser **1:1 en desktop y genuinamente responsive en móvil**, que es justo lo que el usuario pidió con los skills de adaptive/responsive.

Breakpoints propuestos para el clon:

| BP | Layout |
|---|---|
| `< 600` | Rail colapsado (solo iconos) + drawer overlay; contenido 1 columna; tab strip con scroll horizontal; toolbar como `BottomNavigationBar` |
| `600–1023` | Sidebar colapsable, contenido 1 columna, cards 2 col |
| `1024–1439` | Sidebar visible, cards 3 col, workspace con split panes apilables |
| `≥ 1440` | Layout 1:1 exacto: rail + sidebar + split panes horizontales |

---

## 6. Alcance de la paridad 1:1

**Se replica 1:1:**
- Estructura completa: rail, sidebar, tab strip, toolbar, sub-toolbar, panel de recurso, split panes
- Los 9 destinos de navegación y sus menús exactos
- Todos los tokens de color, tipografía y métrica
- Interacciones: colapsar sidebar, abrir/cerrar pestañas, cambio de tab activa, zoom
- Comportamiento de panel de control y tarjetas

**Se adapta (no se copia literal):**
- Todo el layout en `< 600px`, porque el original se rompe
- Contenido real: Logos tiene ~250k libros bajo licencia. El clon trae un corpus
  abierto de dominio público (Biblia RVR60 y similares) + estructura lista para
  conectar una API propia.

**Fuera de alcance:** backend de Logos, Algolia, sincronización con Faithlife,
LMS, y funciones que dependen de licencia (Lexham, sermon builder,etc.).
