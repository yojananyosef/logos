import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../data/services/amf_reader.dart';
import '../../../../domain/models/reader_settings.dart';
import '../../../../domain/reader/reader_find.dart';
import '../../../../domain/search/logos_text.dart';
import '../../core/theme/logos_colors.dart';
import '../../core/theme/logos_theme.dart';
import '../../core/theme/reading_palette.dart';
import 'view_models/reader_view_model.dart';

/// What one run of the rendered chapter is, which decides how it is drawn.
enum SegmentRole {
  /// Scripture text.
  body,

  /// A verse number, in whichever of the three styles the reader chose.
  verseNumber,

  /// A run of text a find term matched.
  findHit,

  /// The run a find term matched, and the one the reader is standing on.
  findHitActive,

  /// A cross-reference, in the link colour and tappable.
  crossReference,
}

/// One passage a cross-reference points at, already resolved to a book this module has.
class CrossReferenceTarget {
  const CrossReferenceTarget({
    required this.osisCode,
    required this.label,
    required this.chapter,
    required this.verse,
    this.verseEnd,
  });

  /// OSIS code of the target book, so the reader can navigate by it.
  final String osisCode;

  /// How the target is written in the reference marker, e.g. `Jn 1:3-10`.
  final String label;

  final int chapter;
  final int verse;
  final int? verseEnd;

  /// Whether this module declares the target book.
  ///
  /// A reference into a book the module lacks is still drawn — the reader may have another
  /// translation installed that has it — but it is marked so the view can say so instead of
  /// navigating to a chapter that will not load.
  bool get isPresent => osisCode != unknownBook;
}

/// The OSIS code a target carries when the module does not declare its book.
///
/// A placeholder rather than null so the marker still renders: a reference pointing outside
/// the module is information, and hiding it would make the verse look as though it had none.
const String unknownBook = '?';

/// One tappable cross-reference marker and the passages it points at.
class CrossReferenceRun {
  const CrossReferenceRun({required this.label, required this.targets});

  /// The whole marker as drawn, e.g. `(Jn 1:3, 10)`.
  final String label;

  final List<CrossReferenceTarget> targets;

  /// Whether every passage this marker names is in a book the module contains.
  bool get isNavigable => targets.every((t) => t.isPresent);
}

/// One run of the rendered chapter, with the character range it occupies in it.
///
/// The offsets are what let the reader scroll to a match or a verse. Every alternative — a
/// key per verse, an estimated line count — either cannot answer "where" or answers it
/// approximately, and an approximate scroll in a book this application exists for is a
/// scroll to the wrong verse.
class ChapterSegment {
  const ChapterSegment({
    required this.role,
    required this.text,
    required this.start,
    this.verse,
    this.verseTextOffset = 0,
    this.crossReference,
  });

  final SegmentRole role;
  final String text;

  /// Character offset of this run within the whole rendered chapter.
  final int start;

  /// The verse this run belongs to, for anything but plain body text.
  final int? verse;

  /// Where this run starts in the *verse's own* text.
  ///
  /// Carried because a find match's offsets are relative to its verse, and adding them to
  /// the chapter offset without this would land in the middle of a different verse — a
  /// scroll that looks plausible and is wrong.
  final int verseTextOffset;

  final CrossReferenceRun? crossReference;

  bool get isFindHit =>
      role == SegmentRole.findHit || role == SegmentRole.findHitActive;
}

/// The rendered chapter: an ordered list of runs, plus the offsets needed to navigate it.
class ChapterLayout {
  const ChapterLayout({required this.segments});

  final List<ChapterSegment> segments;

  /// Total characters, which is what a `TextPainter` needs to lay the chapter out.
  int get length => segments.fold(0, (n, s) => n + s.text.length);

  /// The whole chapter, laid out as the offset of a verse's number.
  ///
  /// Falls back to the verse's first run, so a chapter in hidden-number style still scrolls
  /// to the right place: with no numbers there is nothing else to aim at.
  int offsetOfVerse(int verse) {
    for (final s in segments) {
      if (s.verse == verse && s.role == SegmentRole.verseNumber) return s.start;
    }
    for (final s in segments) {
      if (s.verse == verse) return s.start;
    }
    return 0;
  }

  /// The chapter offset of [match], or null when the match is not in this chapter.
  int? offsetOfMatch(FindMatch match) {
    for (final s in segments) {
      if (s.verse != match.verse || !s.isFindHit) continue;
      final within = match.start - s.verseTextOffset;
      if (within >= 0 && within + match.end - match.start <= s.text.length) {
        return s.start + within;
      }
    }
    return null;
  }

  /// How many find hits this chapter holds.
  int get findHitCount => segments.where((s) => s.isFindHit).length;

  /// The chapter as one span tree.
  ///
  /// [recognizerFor] is called once per cross-reference and its result attached, because a
  /// sub-run of a `TextSpan` cannot be made tappable any other way. The caller owns the
  /// returned recognizers and must dispose them; a chapter rebuilt on every keystroke leaks
  /// one gesture arena per reference per rebuild otherwise.
  ///
  /// The direction is not set here. It belongs to the `RichText` and the `TextPainter` that
  /// measure the chapter, and setting it in the span as well would let the two disagree —
  /// a measurement taken in one direction and painted in the other produces a scroll
  /// position that looks plausible and is wrong.
  TextSpan toSpan({
    required ReaderSettings settings,
    required ReadingPalette palette,
    GestureRecognizer? Function(CrossReferenceRun run)? recognizerFor,
  }) =>
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(
              text: s.text,
              style: styleFor(s, settings, palette),
              recognizer: s.crossReference == null
                  ? null
                  : recognizerFor?.call(s.crossReference!),
            ),
        ],
      );

  /// The style one run is drawn in.
  ///
  /// Public because a test asserts against it directly — a cross-reference that is the
  /// wrong colour is a defect that no amount of scrolling to it would reveal.
  TextStyle styleFor(
    ChapterSegment segment,
    ReaderSettings settings,
    ReadingPalette palette,
  ) {
    final scripture = LogosTypography.scriptureWith(settings, palette);
    switch (segment.role) {
      case SegmentRole.body:
        return scripture;

      case SegmentRole.verseNumber:
        // Only reached when the style is not hidden: a hidden number produces no run at
        // all, which keeps the offsets in this layout describing exactly the text that is
        // on screen.
        if (settings.verseNumbers == VerseNumberStyle.superscript) {
          return LogosTypography.verseNumber;
        }
        // On the baseline rather than raised, so it reads as a number and not as a
        // footnote marker.
        return scripture.copyWith(
          color: LogosColors.link,
          fontWeight: FontWeight.w600,
        );

      case SegmentRole.findHit:
        return scripture.copyWith(
          color: LogosColors.searchHitText,
          backgroundColor: palette.findHit,
          fontWeight: FontWeight.w600,
        );

      case SegmentRole.findHitActive:
        return scripture.copyWith(
          color: LogosColors.searchHitText,
          backgroundColor: palette.findActiveHit,
          fontWeight: FontWeight.w700,
        );

      case SegmentRole.crossReference:
        // `link-color`, #1E6AFE, underlined so it is distinguishable from body text by
        // more than hue — a link the reader cannot see as a link is not navigable by
        // anyone who does not distinguish that blue from every other blue on the page.
        return scripture.copyWith(
          color: LogosColors.link,
          decoration: TextDecoration.underline,
          decorationColor: LogosColors.link,
          fontWeight: FontWeight.w600,
        );
    }
  }
}

/// Builds the rendered runs for one chapter.
///
/// Pure, and deliberately so: the offsets it computes are what the reader scrolls by, and
/// they have to be checkable without a widget, a font or a screen.
///
/// [books] resolves a reference's numeric `toBookId` into something the reader can navigate
/// by, and supplies the abbreviations a marker is labelled with. [activeMatch] is drawn in
/// the active colour and affects nothing else, so the offsets a test measures are the
/// offsets the reader scrolls to.
ChapterLayout buildChapterLayout(
  ChapterView chapter,
  ReaderSettings settings, {
  required List<AmfBook> books,
  List<FindMatch> highlights = const [],
  FindMatch? activeMatch,
}) {
  final label = _BookLabeller(books);
  final segments = <ChapterSegment>[];
  var cursor = 0;

  void add(
    SegmentRole role,
    String text, {
    int? verse,
    int verseTextOffset = 0,
    CrossReferenceRun? reference,
  }) {
    if (text.isEmpty) return;
    segments.add(ChapterSegment(
      role: role,
      text: text,
      start: cursor,
      verse: verse,
      verseTextOffset: verseTextOffset,
      crossReference: reference,
    ));
    cursor += text.length;
  }

  for (final v in chapter.verses) {
    if (settings.verseNumbers.isShown) {
      add(SegmentRole.verseNumber, ' ${v.verse}', verse: v.verse);
    }

    final hits = [for (final m in highlights) if (m.verse == v.verse) m];
    final groups = chapter.referencesFor(v.verse);

    // Where each reference's phrase ends, found against this module's own wording. TSK's
    // anchors are lower-case word forms and the module carries the capitalised text of a
    // printed Bible, so the match is folded.
    final anchorEnds = <AmfAnchoredReferences, int>{};
    for (final g in groups) {
      final end = _anchorEnd(v.text, g.anchor);
      if (end != null) anchorEnds[g] = end;
    }
    final referencesAt = <int, List<AmfAnchoredReferences>>{};
    for (final entry in anchorEnds.entries) {
      referencesAt.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // Walked by position rather than over fixed pairs of boundaries, because a find hit and
    // a reference's phrase can overlap: an anchor may end inside the words a term matched.
    // Walking pairs would then step over the reference and lose the link without any error —
    // which is why this is a cursor and not a `for` over a sorted set.
    final text = v.text;
    var pos = 0;
    while (pos < text.length) {
      // A reference is drawn immediately after the phrase it belongs to, which is what
      // makes the links readable: `Jn 1:3, 10` appears after `gave it being`, the phrase the
      // reader is looking at. Drawn at the end of the verse it would sit half a chapter away
      // from its own cause.
      //
      // Emitted without advancing `pos`: the marker is inserted *at* this point in the text,
      // so the walk continues from the same offset. The body run below is what moves it on —
      // a `continue` here would re-enter at the same position and never terminate.
      final atPosition = referencesAt[pos];
      if (atPosition != null) {
        for (final g in atPosition) {
          final run = _referenceRun(g, label);
          add(SegmentRole.crossReference, ' ${run.label}', verse: v.verse, reference: run);
        }
      }

      final hit = hits.where((m) => m.start == pos && m.end > pos).toList();
      if (hit.isNotEmpty) {
        final h = hit.single;
        // An anchor ending inside the matched words splits the run, so the link lands between
        // them rather than being dropped.
        final innerAnchor = _firstAnchorEndBetween(referencesAt, pos, h.end);
        final cut = innerAnchor ?? h.end;
        _emitFind(
          add,
          v,
          pos,
          cut,
          h,
          activeMatch,
          isActive: innerAnchor == null,
        );
        pos = cut;
        continue;
      }

      final next = _nextBoundary(
        [for (final m in hits) m.start, ...referencesAt.keys],
        pos,
        text.length,
      );
      add(SegmentRole.body, ' ${text.substring(pos, next)} ',
          verse: v.verse, verseTextOffset: pos);
      pos = next;
    }

    // References anchored to the verse's last word: the loop above has already ended, so
    // they are emitted here. Losing them would drop a link for no reason other than that it
    // landed on the final character.
    for (final g in referencesAt[text.length] ?? const <AmfAnchoredReferences>[]) {
      final run = _referenceRun(g, label);
      add(SegmentRole.crossReference, ' ${run.label}', verse: v.verse, reference: run);
    }

    // References whose phrase this module does not contain are drawn at the end of the verse
    // rather than dropped. Losing a link because two editions of a translation word a verse
    // differently is the worse outcome: the reader would see fewer references than the
    // source has, with no way to know why.
    for (final g in groups) {
      if (anchorEnds.containsKey(g)) continue;
      final run = _referenceRun(g, label);
      add(SegmentRole.crossReference, ' ${run.label}', verse: v.verse, reference: run);
    }
  }

  return ChapterLayout(segments: segments);
}

/// The first reference phrase ending strictly after [from] and before [to].
int? _firstAnchorEndBetween(Map<int, List<AmfAnchoredReferences>> referencesAt, int from, int to) {
  int? best;
  for (final at in referencesAt.keys) {
    if (at > from && at < to && (best == null || at < best)) best = at;
  }
  return best;
}

/// The next position after [from] at which anything has to be drawn.
///
/// Falls back to [textLength] rather than to the largest candidate: a candidate beyond the
/// end of the verse would make `substring` throw, and a position past the end means the
/// verse is finished however many boundaries it nominally had.
int _nextBoundary(List<int> candidates, int from, int textLength) {
  int? best;
  for (final c in candidates) {
    if (c > from && c <= textLength && (best == null || c < best)) best = c;
  }
  return best ?? textLength;
}

/// Emits the part of a find hit that runs up to [to].
void _emitFind(
  void Function(
    SegmentRole,
    String, {
    int? verse,
    int verseTextOffset,
    CrossReferenceRun? reference,
  }) add,
  AmfVerse v,
  int from,
  int to,
  FindMatch hit,
  FindMatch? activeMatch, {
  required bool isActive,
}) {
  add(
    isActive && hit.start == activeMatch?.start && hit.verse == activeMatch?.verse
        ? SegmentRole.findHitActive
        : SegmentRole.findHit,
    ' ${v.text.substring(from, to)} ',
    verse: v.verse,
    verseTextOffset: from,
  );
}

/// Turns a group of references into the marker the reader draws.
CrossReferenceRun _referenceRun(AmfAnchoredReferences group, _BookLabeller label) {
  final targets = [
    for (final r in group.references)
      CrossReferenceTarget(
        osisCode: label.osisOf(r.toBookId),
        label: '${label.shortOf(r.toBookId)} ${r.toChapter}:${r.toVerse}'
            '${r.toVerseEnd != null && r.toVerseEnd != r.toVerse ? '-${r.toVerseEnd}' : ''}',
        chapter: r.toChapter,
        verse: r.toVerse,
        verseEnd: r.toVerseEnd,
      ),
  ];
  return CrossReferenceRun(label: ' (${targets.map((t) => t.label).join('; ')})', targets: targets);
}

/// Where [anchor] ends in [text], or null when this module words the phrase differently.
int? _anchorEnd(String text, String anchor) {
  if (anchor.isEmpty) return null;
  final spans = LogosText.spansInOriginal(text, anchor);
  if (spans.isEmpty) return null;
  return spans.first.end;
}

/// Resolves the module's numeric book ids into OSIS codes and abbreviations.
///
/// The reader looks books up by OSIS code, so a reference can only be followed once its
/// `toBookId` has been turned into one. Kept as a small class rather than a map lookup at
/// each use because an id the module does not declare has to be *reported*, not substituted.
class _BookLabeller {
  const _BookLabeller(this._books);

  final List<AmfBook> _books;

  AmfBook? _book(int bookId) {
    for (final b in _books) {
      if (b.bookId == bookId) return b;
    }
    return null;
  }

  /// The OSIS code for a book id, or [unknownBook] when the module does not declare it.
  String osisOf(int bookId) => _book(bookId)?.osisCode ?? unknownBook;

  /// The abbreviation a marker is written with.
  ///
  /// The module's own `abbreviation`, which is the OSIS code for a module this repository
  /// builds. The reference writes its references as `Jn 1:3, 10`, and TSK's own three-letter
  /// forms are close enough to read as scripture shorthand rather than as a code.
  String shortOf(int bookId) => _book(bookId)?.abbreviation ?? unknownBook;
}
