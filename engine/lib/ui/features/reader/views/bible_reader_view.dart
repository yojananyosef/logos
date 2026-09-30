import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../data/services/amf_reader.dart';
import '../view_models/reader_view_model.dart';

/// The Bible reader: a book list beside the text, stacked below the medium breakpoint.
///
/// The chapter is set as prose with inline superscript verse numbers, which is how the
/// reference presents scripture and how a reader of a printed Bible expects to read it.
/// A paragraph per verse would be closer to a list of labelled items, and the reference
/// does not do that.
class BibleReaderView extends StatelessWidget {
  const BibleReaderView({super.key, required this.viewModel});

  final ReaderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      builder: (context, layoutClass) {
        final text = _ChapterPane(viewModel: viewModel);
        final list = _BookList(viewModel: viewModel);

        if (layoutClass.isStacked) {
          return Column(
            children: [
              _ChapterHeader(viewModel: viewModel),
              const Divider(height: 1, color: LogosColors.border),
              Expanded(child: text),
              const Divider(height: 1, color: LogosColors.border),
              SizedBox(height: 220, child: list),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 220, child: list),
            const VerticalDivider(
              width: LogosMeasured.sidebarDividerWidth,
              color: LogosColors.border,
            ),
            Expanded(
              child: Column(
                children: [
                  _ChapterHeader(viewModel: viewModel),
                  const Divider(height: 1, color: LogosColors.border),
                  Expanded(child: text),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.viewModel});

  final ReaderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final book = state.book;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LogosSpacing.lg,
        vertical: LogosSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              book == null ? '' : '${book.name} ${state.chapterNumber}',
              style: LogosTypography.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _NavButton(
            icon: Icons.chevron_left,
            tooltip: 'Capítulo anterior',
            onPressed: state.chapterNumber > 1 ? viewModel.previous : null,
          ),
          _NavButton(
            icon: Icons.chevron_right,
            tooltip: 'Capítulo siguiente',
            // Disabled at the last chapter of the book, so the boundary is visible
            // rather than silently doing nothing.
            onPressed: (book != null && state.chapterNumber < book.chapterCount)
                ? viewModel.next
                : null,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
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

class _ChapterPane extends StatelessWidget {
  const _ChapterPane({required this.viewModel});

  final ReaderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;

    if (state.status == ReaderStatus.loading && state.chapter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ReaderStatus.failed) {
      return _Message(
        text: 'No se pudo abrir el capítulo: ${state.error}',
        color: LogosColors.dangerSurface,
      );
    }

    final chapter = state.chapter;
    if (chapter == null || chapter.verses.isEmpty) {
      return const _Message(
        text: 'Este capítulo no contiene versículos en este módulo.',
        color: LogosColors.surfaceSunken,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: LogosSpacing.lg,
        vertical: LogosSpacing.md,
      ),
      children: [
        if (chapter.isIncomplete) _IncompleteChapterNotice(chapter: chapter),
        ConstrainedReading(
          child: Text.rich(
            _spans(chapter.verses),
            style: LogosTypography.scripture(1),
            // Left-to-right only. A right-to-left module — the Hebrew text, or an
            // Arabic translation — would need the direction carried from the module's
            // manifest, and rendering it LTR would silently reorder the text. Better to
            // be visibly unbuilt than to show scripture in the wrong order.
          ),
        ),
      ],
    );
  }

  /// Scripture runs together as prose, with each verse's number superscripted.
  static TextSpan _spans(List<AmfVerse> verses) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      spans
        ..add(TextSpan(
          text: ' ${v.verse}',
          style: LogosTypography.verseNumber,
        ))
        ..add(TextSpan(text: ' ${v.text} '));
    }
    return TextSpan(children: spans);
  }
}

/// Shown when a chapter does not start at verse 1.
///
/// This exists because the alternative is a reader that opens John 1 and shows it
/// starting at verse 2, with no indication that verse 1 is missing. That failure is
/// invisible to the person reading and fatal to anyone trying to cite the passage, and it
/// is exactly what the upstream KJV and ASV modules do.
class _IncompleteChapterNotice extends StatelessWidget {
  const _IncompleteChapterNotice({required this.chapter});

  final ChapterView chapter;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: LogosSpacing.md),
      padding: const EdgeInsets.all(LogosSpacing.md),
      color: LogosColors.warningSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined,
              size: 18, color: LogosColors.warningIcon),
          const SizedBox(width: LogosSpacing.sm),
          Expanded(
            child: Text(
              'Este módulo no contiene el versículo 1 de este capítulo; '
              'empieza en el ${chapter.startsAtVerse}. El módulo está incompleto.',
              style: LogosTypography.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: color,
        padding: const EdgeInsets.all(LogosSpacing.lg),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.viewModel});

  final ReaderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;

    if (state.books.isEmpty) {
      return const Center(child: Text('Sin libros'));
    }

    return ListView.builder(
      itemCount: state.books.length,
      itemBuilder: (context, index) {
        final book = state.books[index];
        final active = book.osisCode == state.osisCode;
        return InkWell(
          onTap: () => viewModel.show(book.osisCode, 1),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: LogosMeasured.minTouchTarget,
            ),
            color: active ? LogosColors.surfaceHover : null,
            padding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.sm,
            ),
            child: Text(
              book.name,
              style: LogosTypography.navItem.copyWith(
                color: active ? LogosColors.primary : LogosColors.textPrimary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }
}
