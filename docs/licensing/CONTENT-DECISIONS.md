# Decisiones de contenido y licencia

Fecha: 2026-09-29. Estado: aprobado por el usuario. Base de investigación:
`docs/licensing/PD-RESOURCES-INVENTORY.md`.

## 1. Texto bíblico principal — Biblia Platense (Straubinger, 1948)

| Dato | Valor |
|---|---|
| Autor | Juan Straubinger, 1883–1956 |
| Publicación | 1948, La Plata, Argentina |
| Base textual | AT: texto masorético · Deuterocanónicos: Vulgata · NT: Textus Receptus (ed. Merk) |
| Chloride/Spain/EU | Dominio público desde **1 enero 2027** (vida+70, Ley 17.336 art. 10) |
| Estados Unidos | **No PD hasta 2043** (publicada 1948, regla de 95 años) |

Elegida por ser la traducción erudita en español (traducida del hebreo y el griego por un
exégeta, no de la Vulgata) y por incluir deuterocanónicos.

**Canón complements:** Douay-Rheims 1899 (`engDRA`, PD limpio, pre-1931 US y vida+70) para el
canon católico completo en inglés.

### Riesgo residual abierto

Straubinger *"tomó muy seriamente en consideración"* Nácar-Colunga (1944) y Bóver-Cantera (1947).
La base textual declarada es el texto masorético, lo que sugiere referencia comparativa y no
préstamo literal. Si hubiera préstamo literal, se arrastrarían derechos de:

- Benjamín Prado, coautor de Nácar-Colunga (m. 1961) → PD en 2031
- José Cantera Burgos, coautor de Bóver-Cantera (m. 1983) → PD en 2053

Esto **supera** el plazo de Straubinger. Acción requerida antes de la fecha de liberación:
verificación textual de un muestreo de pasajes. Bloqueante para distribución, no para
desarrollo.

### Reglas de distribución

- **No distribuir el catálogo Platense antes del 1 de enero de 2027** en jurisdicciones vida+70.
- **No distribuir en Estados Unidos** sin licencia hasta 2043.
- La app debe funcionar con el catálogo ausente. Esto es exactamente lo que motiva la
  arquitectura de catálogo desacoplado.

## 2. Textos secundarios

| Recurso | Licencia | Uso |
|---|---|---|
| Reina-Valera 1865 | PD | Alternativa en español, riesgo bajo |
| Reina-Valera 1909 (1923) | PD por expiración | Alternativa; ⚠️ sin declaración de la Sociedad Bíblica |
| ASV 1901, KJV, Darby, Young | PD | Paralelos en inglés |
| Douay-Rheims 1899 | PD | Canon católico en inglés |

## 3. Originales y morfología

| Recurso | Licencia | Atribución |
|---|---|---|
| Westminster Leningrad Codex (hebreo) | Dominio público | No |
| SBLGNT (griego) | **CC BY 4.0** | **Sí** |
| OSHB — morfología hebrea por palabra | **CC BY 4.0** | **Sí** |
| Strong's 1890 | Dominio público | No — **derivar del escaneo de Archive.org, nunca del archivo GPL de Open Scriptures** |

**Prohibido:** códigos de Robinson (RCA) — el archivo de CrossWire es CC BY-SA 3.0, obligaciones
de *share-alike*. Morphology de Logos — propietario.

## 4. Comentarios — solo inglés académico, PD

**Elegidos** (todos con módulo SWORD existente):

| Módulo | Autor / edición | Cobertura | Granularidad | Nota |
|---|---|---|---|---|
| `CalvinCommentaries` | Calvin, trad. Calvin Translation Society 1843–57 | 48 libros | **verso** | El mejor. El `.conf` omite Hechos pero el contenido está |
| `KD` | Keil & Delitzsch, trad. James Martin 1864–91 | AT, 10 vols | capítulo | Último AT crítico anterior a Wellhausen |
| `Barnes` | Albert Barnes 1832–34 | NT | capítulo | Exegético real. Requiere parsear los marcadores `Verse N.` |
| `Clarke` | Adam Clarke 1831–34 | ambos | capítulo | Aparato crítico genuino; notas doctrinarias wesleyanas |
| `JFB` | Jamieson/Fausset/Brown 1871–78 | ambos | divisible por verso | Autoría desigual: Fausset fuerte, Brown flojo |

**Referencia:** `ISBE` (James Orr), `Smith` (W. Smith), `AbbottSmith` (léxico griego).

**Excluidos por ser devocionales, no académicos:** `MHC`, `MHCC`, `Wesley`, `Scofield`, `TSK`,
`Abbott`, `PNT`, `Burkitt`, `DTN`, `Geneva`, `Family`.

**Excluido por copyright:** `RWP` (Robertson) — *renewed* 1960, EE.UU. no PD hasta 2029.

### Brecha identificada:material académico PD sin módulo

Bengel, Trapp, Gill, Poole, Ellicott, Lange + McClellan & Yonge, Neander, Plummer (ICC), Hodge,
Briggs, Warfield, Vos, Schaff, ICC, Cambridge Bible — todos inequívocamente PD, **ninguno
disponible como módulo**. Requieren construcción desde CCEL / Wikisource / archive.org con
`osis2mod`. Es el trabajo que aporta erudición real y es trabajo de datos, no de aplicación.

### Nota sobre traducción al español

No existe comentario bíblico en español de dominio público. El "Comentario Matthew Henry" en
español es la traducción de Francisco Lacueva (CLIE, 1983) — obra con derechos. **BAC es una
trampa**: autores antiguos, traducciones modernas con copyright. Cualquier traducción propia
deberá hacerse tras confirmación legal, teniendo en cuenta los derechos *sui generis* de base de
datos de la UE.

## 5. Arquitectura — dos repositorios

**Aprobado: dos repositorios separados**, no monorepo.

- **`logos-engine`** — dominio puro (búsqueda, guías, notas, workflows, lector), UI Flutter, sin
  datos. Consume el contrato del catálogo.
- **`logos-catalogs`** — el contrato, los catálogos y la herramienta CLI de validación legal.

**Por qué:** independencia total de ciclo de release, y el contenido cambia por licencias, no por
código. Es lo que permite desarrollar y publicar la app ahora con el catálogo entrando el
1 de enero de 2027.

El contrato se versiona por separado y la app fija una versión compatible.
