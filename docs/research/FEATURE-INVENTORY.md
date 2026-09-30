# Inventario de funcionalidades de Logos — contrato de alcance

Base del alcance de `logos-full-parity`. Metodología: corpus completo del centro de ayuda de
Logos (330 artículos vía API Zendesk) + matriz oficial de plataformas + página What's New +
release notes + Verbum docs.

**Regla de parada:** todo lo listado aquí está dentro del alcance. Lo que no esté listado,
queda fuera. Este documento es el contrato contra el que se mide la paridad.

## 1. Shell, navegación y workspace

| Función | Descripción | Plataforma |
|---|---|---|
| Command Box | Lanzador universal; libro/pasaje/herramienta/comando con resultados agrupados | Desktop, Web |
| Toolbar | Rail principal, reubicable izquierda/arriba | Desktop |
| Shortcut Bar | Tira arrastrable de recursos y comandos favoritos | Desktop |
| Dashboard | Zonas Ask, Get Started, Explore; 20+ tipos de tarjeta | Todas |
| Layouts | 6 disposiciones + 9 QuickStart + guardados + snapshots | Desktop, Web, Tablet |
| Get Started Wizard | Actividad → layout generado | Desktop |
| New Tab panel | Lanzador contextual; modo "Reference" vs "Everything" | Desktop |
| Link Sets | N paneles ligados a una referencia; modos Follow/Align/Scroll | Todas |
| Paneles flotantes | Float, dock, duplicate, full screen | Desktop |
| Multi-monitor | Logos en dos monitores | Desktop |
| Perfiles multi-cuenta | Cambio de usuario, "Clear users" | Desktop |
| Program Settings | ~40 ajustes (ver `settings`) | Desktop |
| Themes | System / Light / Dark | Desktop |
| Sincronización | Docs y settings entre máquinas, sync manual | Desktop |
| Campana de notificaciones | Contador + anillo de créditos IA (3 estados) | Todas |
| Help Center embebido | Buscable, con scope por plataforma y vídeos | Desktop, Web, Mobile |
| Logos Store | Panel de tienda integrado | Desktop |

## 2. Biblioteca y recursos

Library con facetas · Top Bibles · Prioritize Books · Parallel Resource Sets · Downloaded vs
Cloud · Offline resources · Print Library catalog · Export Library a hoja de cálculo · Hide
Books · Collections · Custom Series · Personal Books (build pipeline con log) · PDF import ·
Reference Scanner (mobile) · Digital Asset Manager · Document Trash

## 3. Taxonomía de herramientas (desktop)

Agrupadas por función — **esta es la columna vertebral del clon**:

- **Reference**: Atlas, Advanced Timeline, Bible Browser, Bible Sense Lexicon, Factbook, Courses, Reading Lists, Bible Books Explorer
- **Content**: Media, Charts
- **Lookup**: Information Tool, Power Lookup, Cited By, Pronunciation
- **Passage**: Explorer, Passage Analysis (5 modos), Text Comparison, Copy Bible Verses
- **Study**: Study Assistant, Summarize
- **Notes**: Notes
- **Utilities**: Personal Books, Program Settings, Add PDF
- **Library**: Collections, custom series, Favorites
- **Pinned**: Factbook, Passage Guide, Exegetical Guide, Bible Word Study, Topic Guide, Sermon Starter Guide, Study Assistant

## 4. Búsqueda

**Motores:** All, Books, Bible, Factbook, Docs, Media, Maps, Factbook Tags, Morph Search, Morph
Query, Clause Search, Syntax Search, Smart Search, Bookstore, Inline.

**Vistas de resultado Biblia:** Passages, Aligned, Grid, Analysis, Fuzzy.

**Operadores precisos:** `AND` `OR` `NOT` `EQUALS` `NOT EQUALS` `INTERSECTS` `THEN` `BEFORE`
`AFTER` `NEAR` `WITHIN n WORDS|CHARS` `IN (a Milestone)` `IN (a Label)` paréntesis, comillas,
`*` `?`.

**Prefijos de ámbito:** `bible:` `lemma.` `sense:` `milestone:` `place:` `topic:` `event:`
`person:` `speaker:` `addressee:` `figure:` `culturalconcept:` `preachingtheme:`
`theologicaltopic:` `title ~` `author ~` `date ~` `editor ~`.

**Modificadores:** Match Case, Match All Word Forms, Reference Matching (Narrow/Default/Broad).

**Otros:** Search Templates, Search Suggestions/autocomplete, Visual Filters (Books/Bible/Morph),
resultados con Facetbook, Books descargadas vs cloud.

## 5. Guías y workflows

**Guías:** Passage Guide, Exegetical Guide, Bible Word Study, Topic Guide, Sermon Starter Guide,
Guide Editor. Secciones: Commentaries, Cross References, Systematic Theology, Biblical Theology,
Biblical People/Places/Things/Events, Media, Journals, Sermons, Sermon Documents, Outlines,
Parallel Passages, Figurative Language, Thematic Outlines, Illustrations, Topical Links, Textual
Variants, Grammars, Grammatical Constructions, Lemma in Passage, Important Words/Passages,
Cultural Concepts, Bible Facts, NTUOT Interactive, Atlas, Charts, Q&A.

**Workflows:** Devotional Study (Devotional, Lectio Divina, Praying Scripture, Adoration) ·
Bible & Topic Study (Basic, Inductive, Person, Place, Theme, Topic, Passage Exegesis, Word
Study, Regular Reading, Heiser, West, Rosner) · Sermon Preparation (Chapell, Allen, Robinson,
Shaddix, Expository, Topical, Expanded Christ-Centered). Workflow Editor.

## 6. Lector

Toolbar dinámica: Home, Search, Notes, Formatting, View, Share, Tools. Insights sidebar (Related
Books, Related Passages, Cross References, Textual History). Biblical Events Navigator. Read
Aloud. Corresponding Text. Copy Bible Verses. Passage block formats.

## 7. Originales

Traditional Interlinear · Reader's Edition Interlinear · Reverse Interlinears · Morphology ·
Lexicons (meaning-focused y theological) · Strong's · Louw-Nida · Bible Sense Lexicon ·
Lexham Semantic Roles · Lemma in Passage · Clause/Syntax Search · Sentence Diagrams · Semantic
domains · Root analysis · Greek/Hebrew keyboards · Transliteration formats · Textual criticism ·
Grammatical Constructions · Figurative Language.

## 8. Referencia y visual

Factbook con lens ribbon (Library/Theological/Counseling/Discover) · Factbook Tags · Church
History Themes · Atlas · Advanced Timeline · Bible Books Explorer · Explorer · Cited By ·
Information Tool · Bible Browser · Datasets (Longacre Genre, Systematic Theology Xrefs ~830k,
Word Senses, Semantic Roles, Events, Persons/Places/Things, Saints, Cultural Concepts, Preaching
Themes, Theological Topics, Figurative Language, Q&A, Speaker/Addressee, Milestone, Louw-Nida,
Strong's, Lectionary, Deuterocanon).

## 9. Notas y highlights

Notes tool · Note creation paths · Filtros (Type, Book, Reference, Tags, Author, Anchor,
Modified, Created) · Rich text editor · Anchors (Active Reference / Reference, múltiples) ·
Auto metadata · Tags · Labels (Name/Attribute/Value) · Notebooks · Sharing (público/grupo
colaborativo) · Export (Rich Text, Plain Text, Web Page, PDF/XPS, Image, Spreadsheet, Calendar,
Citation) · Journaling · Highlights con palettes · Highlight labels · Workflow notes · Guide
notes · Corresponding Notes · Note trash.

## 10. IA

Smart Search · Smart Bible Search · Smart Synopsis · Search Results Summaries · Study Assistant ·
Summarize · Translate · Factbook Questions to Ask · Sermon Assistant (Outlines, Illustrations,
Applications, Questions) · Bible Study Builder · AI Credits.

## 11. Sermón

Sermon Builder (manuscript+slides+handout+questions) · Passage insertion con slide ·
Sermon Manager (Week Grid / Radial Calendar) · Sermon templates · Metadata · Import .docx ·
Export/publish · Preaching Mode · Logos Sermons · Sermon & Bible Study markers · Popular
Quotations · Thematic Outlines export.

## 12. Planes de lectura y devocionales

Reading Plan Manager + wizard · In-text ribbons · Group Reading Plans · Read Later ·
Lectionary card y layouts · Sermon Manager lectionary overlay · Daily Devotionals · Prayer
Lists · Saints · Catholic datasets.

## 13. Documentos

Bible Study · Bibliography · Canvas · Clippings · Morph Query · Passage List · Prayer List ·
Reading Plan · Sentence Diagram · Sermon · Syntax Search · Visual Filter · Word Find Puzzle ·
Word List (con Merge, grouping y **Word Cards**).

> **Nota:** no existe un sistema de flashcards con repetición espaciada en Logos. Lo más
> cercano es Word List → Word Cards: tarjetas imprimibles, unidireccionales, sin SRS. El clon
> implementa eso, no un SRS.

## 14. Media

Media Tool/Browser · Slide editor · Visual Copy · Slide export · Media upload · Digital Asset
Manager · Atlas/Carta · Canvas · Sentence Diagrams · Charts · Visual Filters · Image insertion
in Notes · Sermon → Proclaim/PowerPoint.

## 15. Exportación e interoperabilidad

Print/Export dialog · Formatos (Rich Text, Plain Text, Web Page, XPS/PDF, Image, Spreadsheet,
Calendar, Citation) · Citation styles (APA, Chicago, MLA, Turabian) · Bibliography documents ·
Clippings → Passage List/Bibliography · `ref.ly` deep links · Copy Location · 100-page export cap.

## 16. Solo móvil

Draw on Screen · Reference Scanner (cámara) · Print Library ISBN Scanner · Text Selection Cards.

## 17. Solo desktop

Factbook Tags · Power Lookup · Personal Books · Guide/Workflow Editor · Search Templates ·
Print/Export · Morph/Syntax/Clause/Media/Maps/Docs Search · Bible Sense Lexicon · Topic Guide ·
Bible Books Explorer · Kiosk Mode · Print Library Catalog · Community Tags · Bibliography ·
Multiple Book Display.

## 18. Solo web (o superior en web)

Insights sidebar disponible a todos los usuarios en web (Premium+ en desktop/mobile) ·
Prioritize Books se gestiona en desktop pero se consume en web/mobile · Reading Plans se crean
en desktop/web y en móvil desde junio 2026 · Preaching Mode en desktop abre navegador ·
Canvas en iPad pero no en tablets Android.

## Fuentes

- `support.logos.com/hc/en-us/articles/9785956686349-Logos-Platform-Comparison` (matriz)
- `support.logos.com/hc/en-us/articles/360016752291-Toolbar-Navigation`
- `support.logos.com/hc/en-us/articles/360017893592-Using-Guides`
- `support.logos.com/hc/en-us/articles/360018035692-What-guided-study-options-does-Logos-offer`
- `support.logos.com/hc/en-us/articles/35181728416397-How-Logos-uses-AI`
- `logos.com/whats-new`
- Help Center API, 330 artículos
