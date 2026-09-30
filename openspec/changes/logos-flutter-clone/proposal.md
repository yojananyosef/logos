# Proposal

## Why

Logos Bible Software es la herramienta de estudio bíblico más completa del mercado, pero su
aplicación web (`app.logos.com`) está atada a un navegador, a un corpus de ~250 000 libros bajo
licencia de Faithlife, y —verificado en 4 viewports reales— **no es responsive**: a 390 px el
sidebar conserva 207 px fijos y el contenido desborda horizontalmente, sin ningún breakpoint.

Se quiere un clon funcional 1:1 en **Flutter**, de modo que la misma base de código corra en
Android, iOS, web y escritorio ("escribir una sola vez"), conservando la estructura exacta del
workspace de Logos (rail + sidebar + pestañas + split panes + toolbar) pero **realmente
adaptativo**, algo que el original no es.

El análisis ya está hecho: se recorrió la app real con Playwright y se extrajeron sus 1893 design
tokens CSS, que quedan en `docs/research/design-tokens.json` como fuente de verdad del tema.

## What Changes

- **Nuevo proyecto Flutter** (`lib/` con arquitectura feature-first + Riverpod + go_router)
  multipataforma: Android, iOS, Web, Linux, macOS, Windows.
- **Paridad 1:1 de la estructura del workspace**, replicada desde la app real:
  rail de iconos con campo `Pasaje o tema`, sidebar de 9 destinos + `Acciones Rápidas` + pie
  (`Centro de ayuda`, `Entornos`, `Cerrar todos los paneles`), strip de pestañas de recurso
  con badge de accesibilidad y cerrar, toolbar de 6 secciones, sub-toolbar de contenido, panel
  de recurso con header `recurso › capítulo`, y split panes apilables.
- **Los 9 destinos de navegación** con su comportamiento real: `Panel de Control`,
  `Biblioteca`, `Buscar`, `Biblia`, `Asistente de estudio`, `Enciclopedia bíblica`,
  `Guías de Estudio`, `Notas`, `Herramientas` (con Atlas focalizado, Comparación de versiones,
  Cursos, Documentos, Enciclopedia bíblica, Información, Recursos gráficos).
- **Tema 1:1** derivado de los tokens reales: primario `#154ac9`, navy `#030b60`, link `#1e6afe`,
  hover `#4797ff`, azul claro `#e9f5ff`, bordes `#e7e7e7`/`#cccccc`, texto `#333333`/`#515d72`,
  Source Sans Pro, tab activa con borde inferior `2px` de `#154ac9`.
- **Layout adaptativo en 4 breakpoints** (`<600`, `600–1023`, `1024–1439`, `≥1440`) — la
  divergencia deliberada frente al original, que se rompe por debajo de 600 px.
- **Lector de Biblia funcional** con corpus de dominio público (RVR60 y compañía), notas al pie,
  referencias cruzadas navegables, zoom, vista por páginas, barra localizadora y pantalla
  completa.
- **Buscador** con los operadores básicos reales (`O`, `Y`, `NO`, `ANTES`, `DESPUÉS`, `CERCA`,
  comodines `*` y `?`) y el panel de sintaxis/documentación que Logos muestra sin consulta.
- **Panel de Control** con banner, sección `EXPLORAR` en masonry de 4 tipos de tarjeta
  (Anuncio, Novedades, Pre-order, Banner de servicio) y `De su biblioteca`.
- **Accesibilidad**: modo de vista limitada, targets táctiles ≥44 px, navegación por teclado,
  y respectado de `prefers-reduced-motion`.
- **Fuera de alcance**: backend, autenticación contra Faithlife, Algolia, LMS y toda función
  que requiera licencia de Faithlife. El corpus se sustituye por dominio público y la capa de
  datos queda detrás de una interfaz `LibraryRepository` intercambiable.

## Capabilities

### New Capabilities

- `workspace-shell`: Estructura del workspace de Logos — rail de iconos, sidebar colapsable,
  strip de pestañas, toolbar, sub-toolbar, panel de recurso y split panes.
- `adaptive-layout`: Breakpoints,Drawer móvil, bottom navigation, reflow de cards y
  comportamiento sin desbordamiento horizontal entre 360 px y 1440 px+.
- `design-system`: Tokens de color, tipografía, espaciado y componentes base derivados 1:1 de
  los tokens CSS reales de Logos.
- `library-browser`: Navegación de la biblioteca con búsqueda, filtros y grid/listado de recursos.
- `bible-reader`: Lector de texto bíblico con capítulos y versículos, notas al pie, referencias
  cruzadas, zoom, vista por páginas, barra localizadora y pantalla completa.
- `search-syntax`: Parser y ejecutor de la sintaxis de búsqueda de Logos, incluidos operadores
  booleanos, de proximidad, comodines y referencias.
- `home-dashboard`: Panel de inicio con banner, `EXPLORAR` en masonry y `De su biblioteca`.
- `study-tools`: Contenedor de `Herramientas` con Atlas focalizado, Comparación de versiones,
  Cursos, Documentos, Información y Recursos gráficos.

### Modified Capabilities

Ninguna — el proyecto no tenía especificaciones previas.

## Impact

- **Nuevo**: proyecto Flutter completo en `lib/`, `test/`, `web/`, `android/`, `ios/`, y
  carpetas de escritorio generadas por `flutter create`.
- **Dependencias**: `flutter_riverpod` (estado), `go_router` (navegación), `google_fonts`
  (Source Sans Pro), `flutter_test` / `mocktail` (pruebas). Sin backend ni base de datos en
  esta fase: el corpus va empaquetado como assets.
- **Documentación**: `docs/research/` ya contiene el análisis, 12 capturas reales, los volcados
  de texto de las 9 pantallas y `design-tokens.json`.
- **Riesgo conocido**: el texto de las Biblias y de las obras de los autores está bajo derechos de
  autor. El clon usa exclusivamente obras de dominio público y no replica contenido
  protegido de Faithlife; la estructura queda lista para conectar una fuente propia.
- **Toolchain**: Flutter 3.24.5 / Dart 3.5.4 (SDK instalado en `/tmp/opencode/flutter`).
