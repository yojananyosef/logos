import 'package:flutter/material.dart';

import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../domain/search/search_query.dart';

/// The syntax help panel, shown while the search field is empty.
///
/// The content, wording and grouping are the reference's own, captured from its search
/// screen. Every example is a live button: activating one puts that query in the field and
/// runs it, so the panel teaches the syntax by doing it rather than by describing it.
class SyntaxHelpView extends StatelessWidget {
  const SyntaxHelpView({super.key, required this.onExample});

  /// Runs the example the user chose.
  final void Function(String example) onExample;

  /// The reference's own six opening lines, in its order.
  static const _introduction = <({String text, String? example})>[
    (
      text: 'Si escribe dos palabras (por ejemplo, ',
      example: null,
    ),
    (text: '', example: 'amor al prójimo'),
    (
      text: '), se realizará una búsqueda de artículos que contengan ambas palabras.',
      example: null
    ),
    (text: 'Para buscar cualquiera de las dos palabras, utilice ', example: null),
    (text: '', example: 'amor O prójimo'),
    (text: '.', example: null),
    (text: 'Ponga las frases exactas entre comillas: ', example: null),
    (text: '', example: '"hijo del Hombre"'),
    (text: '.', example: null),
    (
      text: 'Un asterisco representa cualquier número de caracteres en una palabra, '
          'por ejemplo. ',
      example: null
    ),
    (text: '', example: 'Crist*'),
    (text: ' coincide con ', example: null),
    (text: '', example: 'Cristo'),
    (text: ' o ', example: null),
    (text: '', example: 'cristiano'),
    (text: '', example: null),
    (
      text: 'Un signo de interrogación representa un solo carácter en una palabra, '
          'por ejemplo. ',
      example: null
    ),
    (text: '', example: 's?n'),
    (text: ' coincide con ', example: null),
    (text: '', example: 'el pecado'),
    (text: ', ', example: null),
    (text: '', example: 'el hijo'),
    (text: ' y ', example: null),
    (text: '', example: 'el sol'),
    (text: '', example: null),
    (text: 'Busque referencias bíblicas como esta: ', example: null),
    (text: '', example: 'Biblia:"Jn 3:16"'),
    (text: '.', example: null),
  ];

  /// The `Operadores básicos` rows, each with the examples the reference shows beside it.
  static const _operators = <({String label, List<String> examples})>[
    (
      label: 'solo una palabra u otra:',
      examples: ['Cristo O Jesús'],
    ),
    (
      label: 'Ambas palabras:',
      examples: ['Cristo Y Jesús', 'Cristo Jesús'],
    ),
    (
      label: 'Una palabra, pero no la otra:',
      examples: ['Cristo NO Jesús'],
    ),
    (
      label: 'Una palabra antes que otra:',
      examples: ['Cristo ANTES Jesús'],
    ),
    (
      label: 'Una palabra después de otra:',
      examples: ['Cristo DESPUÉS Jesús'],
    ),
    (
      label: 'Una palabra cerca de otra:',
      examples: [
        'Cristo CERCA Jesús',
        'Cristo DENTRO 2 PALABRAS Jesús',
        'Cristo DENTRO 10 CARACT Jesús',
      ],
    ),
  ];

  /// The `Buscar palabras clave` rows.
  static const _keyword = <({String label, String? example, List<String> examples})>[
    (
      label: 'Referencias bíblicas:',
      example: null,
      examples: ['Biblia:"Jn 3:16"', 'evangelismo CERCA Biblia:"Juan 3"'],
    ),
    (
      label: 'Encuentre cualquier referencia a los versículos dentro de Juan 3, '
          'o el capítulo en su totalidad:',
      example: 'Biblia:"Juan 3"',
      examples: [],
    ),
    (
      label: 'Encuentre una referencia exacta a Juan capítulo 3:',
      example: 'Biblia:="Juan 3"',
      examples: [],
    ),
  ];

  static const _links = <({String label, String url})>[
    (label: 'Manual de Ayuda', url: 'https://help.logos.com'),
    (label: 'Wiki editado por usuarios', url: 'https://wiki.logos.com'),
    (label: 'Grupo de búsqueda Logos', url: 'https://community.logos.com'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LogosSpacing.lg),
      children: [
        _IntroductionCard(onExample: onExample, lines: _introduction),
        const SizedBox(height: LogosSpacing.lg),
        _OperatorsSection(rows: _operators, onExample: onExample),
        const SizedBox(height: LogosSpacing.lg),
        _KeywordSection(rows: _keyword, onExample: onExample),
        const SizedBox(height: LogosSpacing.lg),
        const _LinksSection(links: _links),
      ],
    );
  }
}

/// A runnable example, styled as the reference's code chip.
class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Usar esta búsqueda',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
        child: Container(
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: LogosSpacing.sm,
            vertical: LogosSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: LogosColors.searchChip,
            borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
          ),
          child: Text(
            text,
            style: LogosTypography.code.copyWith(color: LogosColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// The opening card: a blue left rule and the six lines of examples.
class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard({required this.lines, required this.onExample});

  final List<({String text, String? example})> lines;
  final void Function(String) onExample;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LogosColors.surface,
      padding: const EdgeInsets.all(LogosSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The reference marks the panel with a coloured left rule rather than a border
            // on all four sides, which is what makes it read as a note and not a card.
            Container(width: 3, color: LogosColors.infoIcon),
            const SizedBox(width: LogosSpacing.md),
            Expanded(
              child: Wrap(
                spacing: LogosSpacing.xs,
                runSpacing: LogosSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final line in lines)
                    if (line.example != null)
                      _ExampleChip(
                        text: line.example!,
                        onTap: () => onExample(line.example!),
                      )
                    else
                      Text(line.text, style: LogosTypography.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled section with a rule under the title, as the reference draws them.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: LogosTypography.title),
        const SizedBox(height: LogosSpacing.sm),
        const Divider(height: 1, color: LogosColors.border),
        const SizedBox(height: LogosSpacing.sm),
        ...children,
      ],
    );
  }
}

class _OperatorsSection extends StatelessWidget {
  const _OperatorsSection({required this.rows, required this.onExample});

  final List<({String label, List<String> examples})> rows;
  final void Function(String) onExample;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Operadores básicos',
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: LogosSpacing.sm),
            child: _Row(
              label: row.label,
              examples: [
                for (final e in row.examples)
                  _ExampleChip(text: e, onTap: () => onExample(e)),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeywordSection extends StatelessWidget {
  const _KeywordSection({required this.rows, required this.onExample});

  final List<({String label, String? example, List<String> examples})> rows;
  final void Function(String) onExample;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Buscar palabras clave',
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: LogosSpacing.sm),
            child: _Row(
              label: row.label,
              examples: [
                for (final e in row.examples)
                  _ExampleChip(text: e, onTap: () => onExample(e)),
                if (row.example != null)
                  _ExampleChip(
                    text: row.example!,
                    onTap: () => onExample(row.example!),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A label followed by its examples, wrapping when the window is narrow.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.examples});

  final String label;
  final List<Widget> examples;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LogosSpacing.sm,
      runSpacing: LogosSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label, style: LogosTypography.body),
        ...examples,
      ],
    );
  }
}

class _LinksSection extends StatelessWidget {
  const _LinksSection({required this.links});

  final List<({String label, String url})> links;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Ayuda adicional',
      children: [
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: LogosSpacing.xs),
            child: Row(
              children: [
                // Expanded so a long link label wraps instead of overflowing. The row is
                // otherwise sized to its children, and on a narrow phone the label plus the
                // arrow is wider than the panel.
                Expanded(
                  child: Text(
                    link.label,
                    style: LogosTypography.body.copyWith(color: LogosColors.link),
                  ),
                ),
                const SizedBox(width: LogosSpacing.xs),
                // The reference marks external links with an arrow leaving a box. It is
                // drawn rather than imported so the glyph is not an icon-font dependency
                // for a single mark.
                const Icon(Icons.open_in_new, size: 12, color: LogosColors.link),
              ],
            ),
          ),
      ],
    );
  }
}

/// Exposed for tests: the operator rows, so a test can assert the panel's content without
/// walking the widget tree.
List<SearchOperator> get documentedOperators => SearchOperator.values;
