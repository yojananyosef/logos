# Evaluación: aletheia-platform y aletheia-catalog

Fecha: 2026-09-29. Auditoría sobre clones reales de ambos repos (`main` @ `faa2604` y `1a19b66`).
Enfoque pedido: calidad del formato de módulos, distribución, ingeniería, optimización y
rendimiento. No la cantidad de módulos.

## Veredicto en una línea

**El catálogo es rescatable y es el activo más valioso de los dos. La plataforma no se reutiliza
como código. Se hace un proyecto Flutter nuevo, se adopta AMF, y se reconstruye el motor.**

| Activo | Decisión | Motivo |
|---|---|---|
| **AMF v1 spec** | **Adoptar** | Diseño de nivel industrial. Independiente del lenguaje. |
| **`.amod` (WEB)** | **Reutilizar** | Único módulo sin defectos de datos. |
| **`.amod` (ASV, KJV)** | **Reconstruir** | Bug de datos: 260 capítulos sin versículo 1. |
| **ETL (`scripts/`)** | **Reutilizar conArréglelo** | Bien diseñado; le falta el off-by-one y un gate de integridad. |
| **`catalog.json`** | **Reutilizar** | Esquema correcto. |
| **`module-engine` (TS)** | **Portar la lógica** | Diseño ports/adapters limpio; el lenguaje no sirve. |
| **`packages/core` (TS)** | **Como referencia** | Canon, lectura, TTS: conceptos útiles, no código. |
| **`apps/mobile` (Expo/RN)** | **Descartar** | Es React Native. Necesitamos Flutter. |

---

## 1. AMF v1 — el formato es bueno de verdad

Esto no es un formato improvisado. Tiene las decisiones que un formato de contenido necesita y
que la mayoría no toma:

**Determinismo real, verificado.** ZIP con exactamente dos entradas en orden fijo, DEFLATE nivel 9,
timestamps en época DOS cero (1980-01-01), sin campos extra. Dos builds del mismo contenido dan el
**mismo sha256**, y la CI lo comprueba con doble build. Eso hace el contenido reproducible y
auditable — que es exactamente lo que un gate de licencias necesita para ser creíble.

**SQLite como contenedor, no un zip de JSON.** `page_size=8192`, `journal_mode=DELETE` (sin
residuos WAL al distribuir), `application_id=0x414D4F44` para detectar el formato,
`user_version=schemaVersion`, y `VACUUM` al cerrar. Verificado en los 17 `.amod`: los pragmas son
correctos.

**Decisiones de recuperación correctas.** Tablas `WITHOUT ROWID` donde tiene sentido. FTS5 con
**external content** sobre `verses`, así que el texto no se duplica y la base es más pequeña. Y el
tokenizador `unicode61 remove_diacritics 2` — pensado para que "Jesús" encuentre "Jesus" y
"jesus" equivalga a "Jesús". Alguien pensó en español.

**El consumidor no necesita conocimiento externo de versificación.** `books` se puebla con el
canon completo en orden canónico. Eso elimina una clase entera de bugs de integración.

**Evolución disciplinada.** `amf` cambia solo con cambios de contenedor; `schemaVersion` con
cambios de esquema. El caso v1 → v1.1 (tabla `words` para Strong por palabra) es **aditivo**: los
`.amod` v1.0.0 publicados siguen siendo válidos sin reconstruirse, y los lectores ignoran campos
desconocidos. `minReaderVersion` debe igualar `schemaVersion`. Esto está bien pensado.

**Bug de documentación:** el spec dice `application_id = 1096035140`. El valor correcto es
`0x414D4F44 = 1095585604`, que es lo que la implementación usa. El spec está mal, el código
está bien. Trivial de arreglar, pero es el tipo de cosa que hace que un lector desconfíe del
documento.

### El defecto serio: versículo 1 ausente en el NT de ASV y KJV

Auditoría interna de contigüidad sobre los tres módulos de Biblia:

| Módulo | Capítulos | Sin versículo 1 | Total versículos |
|---|---|---|---|
| **ASV** | 1189 | **260** | 30 826 |
| **KJV** | 1189 | **260** | 30 842 |
| **WEB** | 1189 | **0** | 31 095 |

**`John 1:1` no existe en el módulo ASV ni en el KJV.** Tampoco `Matthew 1:1`, `Romans 1:1`,
`Revelation 1:1` — el versículo 1 falta en el capítulo 1 de *cada* libro del NT, más 176
capítulos más.

Causa: `scripts/lib/sword/rawtext.ts:44` usa `lines[verse - 1]`. En SWORD RawText la primera línea
del chunk de capítulo es el marcador de capítulo, así que el versículo N está en `lines[N]`. Es un
carácter de arreglo, pero invalida los dos módulos más usados.

WEB está limpio porque viene de otra ruta de importación (OSIS de eBible, que siempre emite
números explícitos).

**Por qué no lo detectaron:** el E2E de `packages/module-engine/test/e2e.test.ts` lee
**Genesis 1:1** — que está en el AT y funciona. El test pasa mientras el bug llega a producción.
Falta un test de integridad que recorra todos los capítulos.

**Consecuencia para nosotros:** el build necesita un gate de integridad obligatorio — contigüidad
1..N por capítulo, sin duplicados, sin huecos, y recuento contra la versificación canónica. Ya
está en mis tareas 1.8 y 2.x; ahora tiene un motivo concreto.

### Cobertura de datos: Weak en exactamente lo que necesitamos

Los 17 módulos son **todos `PublicDomain` y todos en inglés**. Bien: cero problemas de licencia.

Pero para nuestro caso:

| Necesitamos | ¿Está? |
|---|---|
| Biblia en español | ❌ ninguno (ni Platense, ni RV1865, ni RV1909) |
| Calvin, KD, Barnes, Clarke | ❌ ninguno (están en SWORD pero no se conver­tieron) |
| JFB | ⚠️ sí, pero es el menos académico de los cinco |
| TSK | ⚠️ presente, pero es índice de referencias cruzadas, no comentario |
| Morfología por palabra | ⚠️ solo Strong por palabra, no codes morfológicos |
| Originales (WLC, SBLGNT) | ❌ ninguno |

Confirmado lo que dijiste: **los módulos se descargan de internet y se añaden**. El trabajo
real no es la cantidad, es el pipeline. Ese pipeline existe y funciona.

---

## 2. Distribución — bien resuelta, con un detalle que vale oro

El canal es **git + raw con tags inmutables**, no GitHub Releases:

```
dist/<id>.amod  →  commiteado en git
catalog.json    →  sha256, sizeBytes, downloadUrl
latest.json     →  puntero flotante a la última versión
```

Y el spec documenta, con el nombre exacto, por qué: *"`github.com/.../releases/...` no envía
`Access-Control-Allow-Origin` y rompe la descarga en web."* Eso es un bug real de producción
descubierto por el camino, documentado para que nadie lo repita. Vale más que la mayoría de las
decisiones de arquitectura.

`latest.json` desacopla "descargar el puntero" de "qué versión es la última", así que el cliente no
necesita conocer tags. El instalador valida sha256 **antes** de tocar disco, y luego valida
`application_id` + `user_version` al abrir. Orden correcto: nada se escribe hasta verificar.

**Limitación a considerar:** depender de `raw.githubusercontent.com` ata la distribución a GitHub.
Funciona y es simple. Si alguna vez hace falta CDN o binarios fuera de git, el formato no cambia
—solo el transporte— porque el `downloadUrl` está en el manifiesto.

---

## 3. Ingeniería y arquitectura del motor

**Bien:**

- **Ports and adapters** real. `EnginePorts` con `fs`, `crypto`, `sqlite`, `http` inyectados. Los
  tests usan adaptadores de Node y corren contra datos reales. Es testeable de verdad.
- **11 archivos de test, 1322 líneas**, incluido un E2E que descarga el catálogo real de GitHub y
  instala el ASV de verdad.
- **Usa OpenSpec** como este proyecto. Mismo flujo spec-driven.
- El motor separa `catalog`, `installer`, `registry`, `open-module` y `reader/{bible,commentary,dictionary,search}`. Limpio.
- TTS bimodal con controles de lock screen, highlights, orquestador de 188 líneas. Más maduro de lo
  que esperaría.

**Debilidades:**

- 3034 líneas de `packages/`, 4157 total en TypeScript. **Es un esqueleto, no un motor.** No hay
  búsqueda por morfología, ni guías, ni notas, ni sermones, ni canvas. El alcance real de Logos
  que planificamos (190 requirements) es de otro orden de magnitud.
- TypeScript + Expo/React Native. **Ninguna parte es reutilizable como código en Flutter.** Ni la
  UI, ni el motor, ni el core.
- El formato depende de **FTS5 de SQLite**. En Flutter esto es un riesgo real de portabilidad que
  hay que verificar pronto, sobre todo en web, donde SQLite va por WASM.

---

## 4. Rendimiento

Lo medible:

- FTS5 con external content: el índice no duplica el texto. Base más pequeña, y `ASV` son
  3.4 MB comprimidos para 30 826 versículos. Razonable.
- `page_size=8192`: menos páginas, mejor para lecturas secuenciales de capítulos.
- Índices B-tree explícitos en `words` para `strongs` y `lemma`, con índice parcial `WHERE strongs IS
  NOT NULL` — bien pensado, evita la mitad de las entradas.
- Lectura con `immutable=1` (solo lectura, sin journal) en la apertura.
- Instalación on-demand: el usuario no descarga 55 MB si solo quiere una Biblia.

**Lo que no está:**

- Sin índices en `verses` más allá del `UNIQUE(bookId, chapter, verse)` — suficiente para leer, pero
  una búsqueda de全书 completa (el buscador de Logos busca en toda la biblioteca) escaneará.
- Sin caché de prepared statements ni batch insert documentado.
- Sin benchmarks. No hay números de latencia en el repo.

Nada de esto es descalificador: es trabajo de optimización que hay que hacer, no un defecto de
partida.

---

## 5. Recomendación

**Proyecto Flutter nuevo. Adoptar AMF. Reconstruir el motor. Reutilizar el pipeline.**

El razonamiento: el valor de estos repos está en el **formato** y en el **pipeline de
distribución**, que son agnósticos al lenguaje. El motor y la UI están en el lenguaje equivocado
y cubren una fracción del alcance. Escribirlos en Dart cuesta más que traducirlos — pero
traducirlos significa también decidir el diseño de lectura, guías, notas y búsqueda que el código
actual ni se plantea.

Concretamente:

1. **Copiar y corregir AMF v1** como contrato del catálogo. Corregir el decimal de `application_id`
   y añadir el gate de integridad de datos que falta.
2. **Reconstruir ASV y KJV** tras arreglar el off-by-one. Reutilizar WEB tal cual.
3. **Portar la lógica de `module-engine`** a Dart: la secuencia validar-sha256 → sandbox →
   validar-`application_id` → registrar. Es.translate innecesaria, es la parte valiosa.
4. **Reescribir el ETL** o migrarlo, añadiendo: contigüidad por capítulo, recuento contra
   versificación canónica, verificación de licencia y fecha de liberación (que AMF no tiene).
5. **Reemplazar el juego de módulos**: añadir Platense (con gate de fecha), RV1865, los cinco
   comentarios académicos, WLC y SBLGNT.
6. **Añadir a AMF lo que falta** para nuestro alcance: gate de fecha de liberación y
   jurisdicción, detección de share-alike, y el campo de granularidad que los comentarios
   academics necesitan (verso / capítulo / libro).

**FTS5 sobre Flutter — verificado, y es buena noticia.** Era el riesgo que podía obligar a
cambiar el formato, así que se comprobó antes de escribir Dart.

- **Nativo**: FTS5 funciona con SQLite 3.53.4. Probado `CREATE VIRTUAL TABLE`, `MATCH`,
  tokenizador `unicode61 remove_diacritics 2` (encuentra «Jesús» con `jesus` y con `Jesús`), y
  **external content**, que es justo el modo que usa AMF.
- **Web**: el `sqlite3.wasm` que distribuye drift viene de
  `sqlite3_wasm_build/src/sqlite_cfg.h`, que contiene `#define SQLITE_ENABLE_FTS5 1`. FTS5 está
  compilado. Se puede usar el binario precompilado de los releases de drift.
- **AMF usa `journal_mode=DELETE`, no WAL** — y WAL no está soportado en web con drift. La
  elección de AMF ya era compatible con web sin saberlo.

Conclusión: **AMF se adopta tal cual.** No hace falta cambiar el formato por FTS5.

**Lo que había que verificar antes de escribir una línea de Dart:** si FTS5 está disponible en
SQLite sobre las seis plataformas de Flutter, empezando por web. Si no lo estuviera, el formato
necesitaría un fallback — y eso sería una decisión de diseño, no un detalle de implementación.

## Two distinct verse-addressing defects, verified against the real modules

Both were found by reading the artefacts rather than the documentation, and they are
different bugs with the same consequence: a reference the user types does not resolve.

### 1. Lost first verse — KJV and ASV, 260 chapters each

`John 1:1` returns **zero rows**. Every affected chapter begins at verse 2. The cause is
the RawText reader indexing a chapter's lines as `lines[verse - 1]` when the first line of
a SWORD RawText chapter chunk is the chapter marker, so verse N lives at `lines[N]`.

The upstream end-to-end test read `Genesis 1:1` — Old Testament, unaffected — and passed.

Verified: 260 chapters start at a verse other than 1 in both modules.

### 2. Merged verses, `verseEnd` never populated — WEB, 4 chapters

`Luke 17:36`, `Acts 8:37`, `Acts 15:41` and `Acts 24:27` all return **zero rows** — but
unlike the first defect, **the text is present**. USFM writes several verses as one run
under a range marker, and the ETL stores that run under the first verse number and leaves
`verseEnd` NULL:

```
Luke 17:35  "There will be two grinding grain together. One will be taken and the other will be left."
```

That is both 17:35 and 17:36. Every chapter still *starts* at verse 1, so a check for
missing first verses alone reports WEB as sound — which is why an earlier note in this
repository called WEB "clean (0 missing)". **That was wrong**, and this section is the
correction.

For a study application this second defect is the worse of the two. A missing chapter is
obviously missing. Text that is visible one line above while the reference the user typed
returns nothing looks like a bug in the app.

### Consequences for this build

- `UsfmExtractor` records `verseEnd` from the range marker instead of discarding the tail.
- `AmfBibleDao.singleVerse` matches `verseEnd` spans, so 17:36 resolves to the row that
  holds its text, and returns the row's own numbering so a caller can see what matched.
- `AmfIntegrityChecker` compares the next verse against what the previous row *covers*.
  Comparing against `verse + 1` reports every correctly-built range as a gap.
- `test/real_modules_test.dart` asserts both defects as *expected* against the real
  artefacts, so a rebuild that fixes them fails the test and forces the expectations to be
  revisited. That is the only way a test keeps telling the truth about data it does not own.
