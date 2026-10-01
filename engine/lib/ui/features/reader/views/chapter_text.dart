import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/reader_settings.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../core/theme/reading_palette.dart';
import '../reader_chapter_layout.dart';

/// One chapter of scripture, with its verse numbers, its cross-references and its find
/// hits, as a single run of prose.
///
/// Kept as one `RichText` rather than a list of verses because that is how scripture is set:
/// a paragraph per verse is a list of labelled items, and the reference does not do that.
/// The cost is that a verse cannot be scrolled to by key, so [ChapterText] measures the
/// layout with a `TextPainter` to turn a character offset into a scroll position.
class ChapterText extends StatefulWidget {
  const ChapterText({
    super.key,
    required this.layout,
    required this.settings,
    required this.palette,
    required this.textDirection,
    required this.onCrossReference,
    this.focusOffset,
  });

  final ChapterLayout layout;
  final ReaderSettings settings;
  final ReadingPalette palette;
  final TextDirection textDirection;

  /// Called with the marker that was tapped.
  final void Function(CrossReferenceRun run) onCrossReference;

  /// A character offset to scroll to, or null to stay where the reader is.
  ///
  /// Not a command but a request: the same offset asked for twice in a row is the same
  /// position, so acting on every notification would fight the reader's own scrolling.
  final int? focusOffset;

  @override
  State<ChapterText> createState() => _ChapterTextState();
}

class _ChapterTextState extends State<ChapterText> {
  final _scrollController = ScrollController();

  /// One recognizer per cross-reference, disposed on teardown and on every rebuild.
  final List<GestureRecognizer> _recognizers = [];
  int? _lastHandledFocus;

  @override
  void didUpdateWidget(ChapterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout || oldWidget.palette != widget.palette) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _scrollController.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Scrolls [widget.focusOffset] into view, once per distinct request.
  void _revealFocus(Size available) {
    final offset = widget.focusOffset;
    if (offset == null || offset == _lastHandledFocus) return;
    _lastHandledFocus = offset;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(available, offset));
  }

  /// Scrolls so the character at [charOffset] sits near the top of the viewport.
  ///
  /// Measured with a `TextPainter` laid out with the same span and width as the rendered
  /// text, so the offset is the real one rather than an estimate from a character count.
  /// Deferred to the next frame because it needs the width the render box was actually
  /// given, which is not known during layout.
  void _scrollTo(Size available, int charOffset) {
    if (!mounted || !_scrollController.hasClients) return;

    final painter = TextPainter(
      text: widget.layout.toSpan(
        settings: widget.settings,
        palette: widget.palette,
      ),
      textDirection: widget.textDirection,
      textAlign: widget.settings.alignment,
      // Omitted rather than set to `-1`. `maxLines` is documented as null for unlimited,
      // and `-1` asserts in the constructor — so an unbounded chapter would fail to measure
      // at exactly the moment it is long enough to need scrolling.
    )..layout(maxWidth: available.width);
    final dy = painter
        .getOffsetForCaret(
          TextPosition(offset: charOffset.clamp(0, widget.layout.length)),
          Rect.zero,
        )
        .dy;
    painter.dispose();

    // A third of the way down rather than flush to the top: a verse at the very top edge
    // loses its number off screen, which is the one thing the reader moved there to see.
    final target =
        (dy - available.height / 3).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(constraints.maxWidth, constraints.maxHeight);
        _revealFocus(available);

        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: LogosSpacing.lg,
            vertical: LogosSpacing.md,
          ),
          child: ConstrainedReading(
            child: Text.rich(
              key: const ValueKey('chapter-rich-text'),
              widget.layout.toSpan(
                settings: widget.settings,
                palette: widget.palette,
                recognizerFor: _recognizerFor,
              ),
              textAlign: widget.settings.alignment,
              textDirection: widget.textDirection,
            ),
          ),
        );
      },
    );
  }

  GestureRecognizer _recognizerFor(CrossReferenceRun run) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onCrossReference(run);
    _recognizers.add(recognizer);
    return recognizer;
  }
}

/// The status line for the cross-references in the open chapter.
///
/// Separate from the chapter itself because the number belongs to the header: how many
/// links a chapter has is a property of the chapter, and the reader deciding whether a
/// translation carries them looks for it there.
class CrossReferenceSummary extends StatelessWidget {
  const CrossReferenceSummary({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Text(
      '$count ${count == 1 ? 'referencia cruzada' : 'referencias cruzadas'}',
      style: LogosTypography.sectionLabel,
    );
  }
}
