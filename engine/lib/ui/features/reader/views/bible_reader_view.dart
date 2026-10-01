import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../core/theme/reading_palette.dart';
import '../reader_chapter_layout.dart';
import '../view_models/reader_view_model.dart';
import 'chapter_text.dart';
import 'reader_find_bar.dart';
import 'reader_format_panel.dart';

/// The Bible reader: a book list beside the text, stacked below the medium breakpoint.
///
/// The chapter is set as prose with its verse numbers inline, which is how the reference
/// presents scripture and how a reader of a printed Bible expects to read it. A paragraph
/// per verse would be closer to a list of labelled items, and the reference does not do that.
class BibleReaderView extends StatelessWidget {
  const BibleReaderView({super.key, required this.viewModel});

  final ReaderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => AnimatedBuilder(
        // The preferences are a second source of truth: a text size changed in the format
        // panel changes what this view draws without changing what the reader has read, so
        // the reader alone notifying would leave the text at its old size.
        animation: viewModel.preferences,
        builder: (context, _) => _build(context),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final settings = viewModel.settings;
    final palette = ReadingPalette.of(settings.colourScheme);

    return ColoredBox(
      color: palette.background,
      child: AdaptiveLayout(
        builder: (context, layoutClass) {
          final text = _ChapterPane(viewModel: viewModel, palette: palette);
          final list = _BookList(viewModel: viewModel);

          final chapter = Column(
            children: [
              _ReaderToolbar(viewModel: viewModel, palette: palette),
              const Divider(height: 1, color: LogosColors.border),
              _ChapterHeader(viewModel: viewModel, palette: palette),
              const Divider(height: 1, color: LogosColors.border),
              Expanded(child: text),
            ],
          );

          if (layoutClass.isStacked) {
            return Column(
              children: [
                // Expanded, because [chapter] itself contains an `Expanded`: without a finite
                // height here the chapter's scroll view has nothing to scroll within.
                Expanded(child: chapter),
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
              Expanded(child: chapter),
            ],
          );
        },
      ),
    );
  }
}

/// The reader's own toolbar: find, format, and the way back.
///
/// The workspace toolbar has `Formato` and `Vista` sections, but the reader replaces the
/// whole content area rather than sitting in a tab pane, so it carries its own controls.
/// Duplicating the two sections here rather than reaching into the workspace's state is what
/// keeps the reader usable on its own — which is also how its tests can open it.
class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({required this.viewModel, required this.palette});

  final ReaderViewModel viewModel;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;

    return Container(
      height: 40,
      color: palette.chromeBackground,
      padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.arrow_back,
            tooltip: 'Volver a la posición anterior',
            onPressed: state.canGoBack ? viewModel.goBack : null,
          ),
          const SizedBox(width: LogosSpacing.xs),
          _ToolbarButton(
            icon: Icons.format_size,
            tooltip: 'Formato',
            onPressed: () => ReaderFormatPanel.show(context, viewModel.preferences),
          ),
          _ToolbarButton(
            icon: Icons.search,
            // The same label whether the bar is open or closed: the button toggles it, and
            // its active state is the pressed background. Naming it "close" while the bar's
            // own close button is also on screen would leave two controls with one label and
            // no way for anyone — or any test — to say which is which.
            tooltip: 'Buscar en este recurso',
            isActive: state.isFindBarVisible,
            onPressed: viewModel.toggleFindBar,
          ),
          const Spacer(),
          // The zoom readout is task 8.7. Shown now, and fixed at 100%, so the toolbar's
          // shape is settled before zoom becomes real rather than the readout arriving later
          // and pushing these controls around.
          const Text('100%', style: LogosTypography.sectionLabel),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? LogosColors.surfaceHover : null,
            borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? LogosColors.textSecondary : LogosColors.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.viewModel, required this.palette});

  final ReaderViewModel viewModel;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final book = state.book;
    final chapter = state.chapter;

    return Container(
      color: palette.chromeBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: LogosSpacing.lg,
        vertical: LogosSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book == null ? '' : '${book.name} ${state.chapterNumber}',
                  key: const ValueKey('chapter-header'),
                  style: LogosTypography.title.copyWith(
                    color: ReadingPalette.of(viewModel.settings.colourScheme).foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                CrossReferenceSummary(count: chapter?.crossReferenceCount ?? 0),
              ],
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
            // Disabled at the last chapter of the book, so the boundary is visible rather
            // than silently doing nothing.
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
  const _ChapterPane({required this.viewModel, required this.palette});

  final ReaderViewModel viewModel;
  final ReadingPalette palette;

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

    final find = state.find;
    final layout = buildChapterLayout(
      chapter,
      viewModel.settings,
      books: state.books,
      highlights: find.result?.inChapter(chapter.osisCode, chapter.chapter) ?? const [],
      activeMatch: find.activeMatch,
    );

    final body = Column(
      children: [
        if (chapter.isIncomplete) _IncompleteChapterNotice(chapter: chapter),
        Expanded(
          child: ChapterText(
            // Keyed on the chapter so a new chapter gets a fresh scroll position and a
            // fresh set of recognizers. Without it, a chapter change would keep the
            // previous chapter's scroll offset and open halfway down.
            key: ValueKey('${chapter.osisCode}:${chapter.chapter}'),
            layout: layout,
            settings: viewModel.settings,
            palette: palette,
            textDirection: TextDirection.ltr,
            focusOffset: state.focusVerse == null
                ? null
                : layout.offsetOfVerse(state.focusVerse!),
            onCrossReference: (run) => _follow(run),
          ),
        ),
      ],
    );

    if (!state.isFindBarVisible) return body;

    return Column(
      children: [
        Expanded(child: body),
        const Divider(height: 1, color: LogosColors.border),
        ReaderFindBar(viewModel: viewModel, onClose: viewModel.closeFind),
      ],
    );
  }

  /// Follows the first target of a cross-reference.
  ///
  /// The first rather than the only one: a marker may name several passages — TSK gives
  /// `beginning` at Gen 1:1 five of them — and offering a chooser for each of the hundred
  /// links in a chapter would put a menu on every reference. The marker itself lists them,
  /// and the list is where the choice belongs.
  void _follow(CrossReferenceRun run) {
    final target = run.targets.first;
    if (!target.isPresent) return;
    viewModel.show(target.osisCode, target.chapter, verse: target.verse);
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
