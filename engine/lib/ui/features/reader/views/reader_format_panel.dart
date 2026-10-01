import 'package:flutter/material.dart';

import '../../../../domain/models/reader_settings.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../core/theme/reading_palette.dart';
import '../view_models/reader_preferences.dart';

/// The `Formato` panel: text size, line spacing, font, colour scheme, alignment, verse
/// numbers.
///
/// Every control writes straight through to the shared preferences, so a change is visible
/// in the chapter behind the panel as it is made. A panel that applied on `Aceptar` would
/// need a preview and a cancel path, and the reference shows the text changing live.
class ReaderFormatPanel extends StatelessWidget {
  const ReaderFormatPanel({super.key, required this.preferences});

  final ReaderPreferencesViewModel preferences;

  /// Opens the panel over the reader.
  static Future<void> show(BuildContext context, ReaderPreferencesViewModel preferences) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: LogosColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LogosDimensions.borderRadiusCard)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          child: ReaderFormatPanel(preferences: preferences),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = preferences.settings;

    return Material(
      color: LogosColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LogosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Formato', style: LogosTypography.title),
                ),
                IconButton(
                  tooltip: 'Cerrar el formato',
                  icon: const Icon(Icons.close, color: LogosColors.textSecondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: LogosSpacing.md),

            _Group(
              label: 'Tamaño del texto',
              child: _ChoiceRow<TextSizeStep>(
                values: TextSizeStep.values,
                selected: settings.textSize,
                labelOf: (v) => v.label,
                onSelected: preferences.setTextSize,
              ),
            ),
            _Group(
              label: 'Interlineado',
              child: _ChoiceRow<LineSpacing>(
                values: LineSpacing.values,
                selected: settings.lineSpacing,
                labelOf: (v) => v.label,
                onSelected: preferences.setLineSpacing,
              ),
            ),
            _Group(
              label: 'Fuente',
              child: _ChoiceRow<ScriptureFont>(
                values: ScriptureFont.values,
                selected: settings.font,
                labelOf: (v) => v.label,
                onSelected: preferences.setFont,
              ),
            ),
            _Group(
              label: 'Números de versículo',
              child: _ChoiceRow<VerseNumberStyle>(
                values: VerseNumberStyle.values,
                selected: settings.verseNumbers,
                labelOf: (v) => v.label,
                onSelected: preferences.setVerseNumbers,
              ),
            ),
            _Group(
              label: 'Color del texto',
              child: _ColourRow(
                scheme: settings.colourScheme,
                onSelected: preferences.setColourScheme,
              ),
            ),
            _Group(
              label: 'Alineación',
              child: _ChoiceRow<TextAlignValue>(
                values: TextAlignValue.values,
                selected: TextAlignValue.values.firstWhere(
                  (v) => v.value == settings.alignment,
                  orElse: () => TextAlignValue.start,
                ),
                labelOf: (v) => v.label,
                onSelected: preferences.setAlignment,
              ),
            ),

            const SizedBox(height: LogosSpacing.md),
            _Preview(settings: settings),
            const SizedBox(height: LogosSpacing.lg),
            OutlinedButton(
              onPressed: preferences.reset,
              child: const Text('Restablecer el formato'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LogosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LogosTypography.sectionLabel),
          const SizedBox(height: LogosSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// A row of mutually exclusive choices.
///
/// Built as buttons rather than a `DropdownButton` because every one of these has two to
/// five values and the reader wants to see them all at once — the difference between
/// `Compacto` and `Amplio` is not something a collapsed menu can convey.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LogosSpacing.xs,
      runSpacing: LogosSpacing.xs,
      children: [
        for (final v in values)
          _Choice(
            label: labelOf(v),
            selected: v == selected,
            onTap: () => onSelected(v),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
        child: Container(
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? LogosColors.primary : LogosColors.surface,
            border: Border.all(
              color: selected ? LogosColors.primary : LogosColors.border,
            ),
            borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
          ),
          child: Text(
            label,
            style: LogosTypography.navItem.copyWith(
              color: selected ? LogosColors.textInverted : LogosColors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour schemes, each shown in its own colours.
///
/// Showing the swatch rather than only its name is the point: `Crema` and `Gris` differ by
/// a background a reader has to see to choose between.
class _ColourRow extends StatelessWidget {
  const _ColourRow({required this.scheme, required this.onSelected});

  final ReadingColourScheme scheme;
  final void Function(ReadingColourScheme) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LogosSpacing.sm,
      runSpacing: LogosSpacing.sm,
      children: [
        for (final s in ReadingColourScheme.values)
          _ColourSwatch(
            scheme: s,
            selected: s == scheme,
            onTap: () => onSelected(s),
          ),
      ],
    );
  }
}

class _ColourSwatch extends StatelessWidget {
  const _ColourSwatch({
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final ReadingColourScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReadingPalette.of(scheme);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Color ${scheme.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
        child: Container(
          constraints: const BoxConstraints(minWidth: 96, minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.all(LogosSpacing.sm),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border.all(
              color: selected ? LogosColors.primary : LogosColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
          ),
          child: Center(
            child: Text(
              scheme.label,
              style: LogosTypography.navItem.copyWith(color: palette.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// A few words of scripture in the chosen settings.
///
/// A panel of switches describing a setting the reader has to imagine is weaker than a
/// sample they can read, and the settings that matter most here — size, spacing, alignment —
/// are all visible in four lines of text and invisible in a label.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = ReadingPalette.of(settings.colourScheme);
    return Container(
      width: double.infinity,
      color: palette.background,
      padding: const EdgeInsets.all(LogosSpacing.md),
      child: Text(
        'En el principio creó Dios los heavens y la tierra. Y la tierra era sin forma y '
        'vacía; y tiniebla estaba sobre la faz del abismo.',
        textAlign: settings.alignment,
        style: LogosTypography.scriptureWith(settings, palette),
      ),
    );
  }
}
