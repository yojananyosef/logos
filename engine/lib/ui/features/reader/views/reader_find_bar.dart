import 'package:flutter/material.dart';

import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../core/theme/reading_palette.dart';
import '../view_models/reader_view_model.dart';

/// The find bar: a field, a match count, and the two step controls.
///
/// The count is the load-bearing part. A find that highlights matches but does not say how
/// many there are leaves the reader unable to tell "that is all of them" from "there may be
/// more further on", which is the difference between finishing a search and abandoning one.
class ReaderFindBar extends StatefulWidget {
  const ReaderFindBar({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  final ReaderViewModel viewModel;
  final VoidCallback onClose;

  @override
  State<ReaderFindBar> createState() => _ReaderFindBarState();
}

class _ReaderFindBarState extends State<ReaderFindBar> {
  late final TextEditingController _field =
      TextEditingController(text: widget.viewModel.state.find.term);
  final _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focused on open, because a find bar the reader has to tap into before typing is one
    // extra step for every use. Requested after the first frame because a node cannot take
    // focus during its own build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _run([String? term]) {
    widget.viewModel.find(term ?? _field.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.viewModel.state.find;
    final palette = ReadingPalette.of(widget.viewModel.settings.colourScheme);

    return Container(
      color: palette.chromeBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: LogosSpacing.md,
        vertical: LogosSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _field,
              focusNode: _fieldFocus,
              onSubmitted: _run,
              onChanged: _run,
              style: LogosTypography.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar en este recurso',
                hintStyle: LogosTypography.body
                    .copyWith(fontSize: 14, color: LogosColors.textDisabled),
                filled: true,
                fillColor: LogosColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: LogosSpacing.sm,
                  vertical: LogosSpacing.sm,
                ),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: LogosColors.border),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: LogosColors.border),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: LogosColors.link, width: 1),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          ),
          const SizedBox(width: LogosSpacing.sm),
          _Count(label: session.label, isSearching: session.isSearching),
          _StepButton(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'Coincidencia anterior',
            onPressed: session.hasMatches ? widget.viewModel.previousMatch : null,
          ),
          _StepButton(
            icon: Icons.keyboard_arrow_down,
            tooltip: 'Coincidencia siguiente',
            onPressed: session.hasMatches ? widget.viewModel.nextMatch : null,
          ),
          _StepButton(
            icon: Icons.close,
            tooltip: 'Cerrar la búsqueda',
            onPressed: () {
              widget.onClose();
              widget.viewModel.closeFind();
            },
          ),
        ],
      ),
    );
  }
}

/// The count readout, e.g. `3 de 412` or `Sin coincidencias`.
class _Count extends StatelessWidget {
  const _Count({required this.label, required this.isSearching});

  final String label;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
      child: Text(
        label,
        key: const ValueKey('find-count'),
        style: LogosTypography.sectionLabel.copyWith(
          color: label == 'Sin coincidencias'
              ? LogosColors.danger
              : LogosColors.textSecondary,
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        // 44dp so the control meets the touch minimum even though the glyph is small.
        child: SizedBox(
          width: LogosMeasured.minTouchTarget,
          height: LogosMeasured.minTouchTarget,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? LogosColors.textSecondary : LogosColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
