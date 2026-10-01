import 'package:flutter/foundation.dart';

import '../../../../data/repositories/bible_repository.dart';
import '../../../../data/services/amf_reader.dart';
import '../../../../domain/models/reader_settings.dart';
import '../../../../domain/reader/reader_find.dart';
import 'reader_preferences.dart';

/// Where the reader is, in a form that can be put down and picked up again.
///
/// A value rather than two loose fields because "return to where I was" has to restore a
/// *verse* as well as a chapter, and the chapter alone is not enough: following a
/// cross-reference from the middle of John 1 back to Gen 1 has to land on the verse that
/// was being read, not at the top of the chapter.
@immutable
class ReaderPosition {
  const ReaderPosition({
    required this.osisCode,
    required this.chapter,
    this.verse,
  });

  final String osisCode;
  final int chapter;

  /// The verse the reader was on, or null when it was not on one.
  final int? verse;

  @override
  bool operator ==(Object other) =>
      other is ReaderPosition &&
      other.osisCode == osisCode &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(osisCode, chapter, verse);

  @override
  String toString() => verse == null ? '$osisCode $chapter' : '$osisCode $chapter:$verse';
}

/// A chapter as the reader presents it.
class ChapterView {
  const ChapterView({
    required this.osisCode,
    required this.chapter,
    required this.verses,
    required this.startsAtVerse,
    this.crossReferences = const {},
  });

  final String osisCode;
  final int chapter;
  final List<AmfVerse> verses;

  /// The first verse number present.
  ///
  /// Normally 1. When it is not, the module is defective, and the reader says so rather
  /// than showing a chapter that quietly begins at verse 2. This is not hypothetical: the
  /// KJV and ASV modules of the upstream catalog are missing verse 1 in 260 chapters
  /// each, John 1:1 among them, and their end-to-end test passed because it read an Old
  /// Testament verse.
  final int startsAtVerse;

  /// The cross-references anchored in this chapter, keyed by verse.
  final Map<int, List<AmfAnchoredReferences>> crossReferences;

  /// The chapter is missing its first verse.
  bool get isIncomplete => startsAtVerse != 1;

  /// The phrases this verse carries references on, in source order.
  List<AmfAnchoredReferences> referencesFor(int verse) =>
      crossReferences[verse] ?? const [];

  /// How many references this chapter holds, counting every target.
  int get crossReferenceCount => crossReferences.values
      .expand((groups) => groups)
      .fold(0, (n, group) => n + group.references.length);
}

/// What the reader is doing right now.
enum ReaderStatus { idle, loading, ready, failed }

/// State for one open Bible module.
class ReaderState {
  const ReaderState({
    this.moduleId,
    this.status = ReaderStatus.idle,
    this.books = const [],
    this.osisCode,
    this.chapterNumber = 1,
    this.chapter,
    this.error,
    this.integrity,
    this.focusVerse,
    this.canGoBack = false,
    this.find = const FindSession(),
    this.isFindBarVisible = false,
  });

  final String? moduleId;
  final ReaderStatus status;
  final List<AmfBook> books;
  final String? osisCode;
  final int chapterNumber;
  final ChapterView? chapter;
  final String? error;
  final IntegrityReport? integrity;

  /// The verse the reader should scroll to, set by a jump and cleared once shown.
  final int? focusVerse;

  /// Whether there is somewhere to go back to.
  final bool canGoBack;

  /// What the find bar is currently doing.
  final FindSession find;

  /// Whether the find bar is on screen.
  ///
  /// Separate from [find] because an open bar with nothing typed is a state the reader has
  /// to be able to reach — the field takes focus and waits for the first key. Deriving
  /// visibility from a non-empty term would make the bar impossible to open.
  final bool isFindBarVisible;

  AmfBook? get book {
    for (final b in books) {
      if (b.osisCode == osisCode) return b;
    }
    return null;
  }

  ReaderState copyWith({
    String? moduleId,
    ReaderStatus? status,
    List<AmfBook>? books,
    String? osisCode,
    int? chapterNumber,
    ChapterView? chapter,
    String? error,
    IntegrityReport? integrity,
    int? focusVerse,
    bool clearFocusVerse = false,
    bool? canGoBack,
    FindSession? find,
    bool? isFindBarVisible,
    bool clearError = false,
  }) =>
      ReaderState(
        moduleId: moduleId ?? this.moduleId,
        status: status ?? this.status,
        books: books ?? this.books,
        osisCode: osisCode ?? this.osisCode,
        chapterNumber: chapterNumber ?? this.chapterNumber,
        chapter: chapter ?? this.chapter,
        error: clearError ? null : (error ?? this.error),
        integrity: integrity ?? this.integrity,
        focusVerse: clearFocusVerse ? null : (focusVerse ?? this.focusVerse),
        canGoBack: canGoBack ?? this.canGoBack,
        find: find ?? this.find,
        isFindBarVisible: isFindBarVisible ?? this.isFindBarVisible,
      );
}

/// What the find bar holds, and what it found.
@immutable
class FindSession {
  const FindSession({
    this.term = '',
    this.result,
    this.activeIndex = -1,
    this.isSearching = false,
    this.error,
  });

  /// Nothing typed: the bar is closed and no search has run.
  static const FindSession idle = FindSession();

  final String term;
  final FindResult? result;

  /// Which match the reader is standing on, as an index into [result]'s matches.
  final int activeIndex;

  final bool isSearching;

  /// Set when the search could not run, so the bar can say why instead of claiming there
  /// are no matches.
  final String? error;

  bool get isOpen => term.isNotEmpty || result != null;
  bool get hasMatches => (result?.matches.isNotEmpty) ?? false;
  int get matchCount => result?.count ?? 0;

  /// The match the reader is on, or null when there is none.
  FindMatch? get activeMatch {
    final r = result;
    if (r == null || activeIndex < 0 || activeIndex >= r.matches.length) return null;
    return r.matches[activeIndex];
  }

  /// What the bar reads, e.g. `3 de 412`.
  ///
  /// 1-based because that is what a person counting matches expects; a count starting at
  /// zero reads as though one match were missing.
  String get label {
    if (error != null) return error!;
    if (result == null) return '';
    if (result!.isEmpty) return 'Sin coincidencias';
    return '${activeIndex + 1} de ${result!.count}';
  }

  FindSession copyWith({
    String? term,
    FindResult? result,
    int? activeIndex,
    bool? isSearching,
    String? error,
    bool clearError = false,
  }) =>
      FindSession(
        term: term ?? this.term,
        result: result ?? this.result,
        activeIndex: activeIndex ?? this.activeIndex,
        isSearching: isSearching ?? this.isSearching,
        error: clearError ? null : (error ?? this.error),
      );
}

/// ViewModel for the Bible reader.
///
/// Owns which book and chapter are open, where the reader can go back to, and what the
/// find bar is doing: the verses come from the repository, and no SQL or file access happens
/// here.
class ReaderViewModel extends ChangeNotifier {
  ReaderViewModel(this._repository, this.preferences);

  final BibleRepository _repository;

  /// The reader's display settings, shared across every open Bible.
  ///
  /// Shared rather than per-module on purpose: a text size is a property of the person
  /// reading, not of the translation, and a reader who sized KJV comfortably would find
  /// every other translation reset when they opened it.
  final ReaderPreferencesViewModel preferences;

  ReaderState _state = const ReaderState();
  ReaderState get state => _state;

  /// Where the reader has been, so a cross-reference can be followed and undone.
  ///
  /// Bounded rather than unbounded. A reader can click through a long chain of references
  /// and come back through it, but the history is a convenience, not an undo log — and an
  /// unbounded list on a `ChangeNotifier` is a leak with a plausible-looking shape.
  final List<ReaderPosition> _history = [];
  static const int _historyLimit = 50;

  ReaderSettings get settings => preferences.settings;

  /// Opens a module and shows its first book.
  Future<void> open(String moduleId, {String? osisCode, int chapter = 1, int? verse}) async {
    _state = ReaderState(moduleId: moduleId, status: ReaderStatus.loading);
    _history.clear();
    notifyListeners();

    try {
      final module = await _repository.open(moduleId);
      _state = ReaderState(
        moduleId: moduleId,
        books: module.books,
        integrity: module.integrity,
      );
      notifyListeners();

      await show(
        osisCode ?? module.books.first.osisCode,
        chapter,
        verse: verse,
        recordHistory: false,
      );
    } on Object catch (e) {
      _state = ReaderState(
        moduleId: moduleId,
        status: ReaderStatus.failed,
        error: '$e',
      );
      notifyListeners();
    }
  }

  /// Shows a chapter.
  ///
  /// [recordHistory] is false for the first chapter of a freshly opened module: there is
  /// nowhere to go back to then, and pushing it would make the back control appear
  /// before the reader has done anything.
  Future<void> show(
    String osisCode,
    int chapterNumber, {
    int? verse,
    bool recordHistory = true,
  }) async {
    final moduleId = _state.moduleId;
    if (moduleId == null) return;

    if (recordHistory) _pushHistory();

    _state = _state.copyWith(
      status: ReaderStatus.loading,
      osisCode: osisCode,
      chapterNumber: chapterNumber,
      clearError: true,
      focusVerse: verse,
      clearFocusVerse: verse == null,
      canGoBack: _history.isNotEmpty,
    );
    notifyListeners();

    try {
      // The chapter and its references are fetched together. A reader that showed the
      // chapter first and the links a frame later would flash text without its references
      // every time it opened a chapter, which reads as the links being unreliable.
      final results = await Future.wait([
        _repository.chapter(moduleId, osisCode, chapterNumber),
        _repository.crossReferences(moduleId, osisCode, chapterNumber),
      ]);
      final verses = results[0] as List<AmfVerse>;
      final references = results[1] as Map<int, List<AmfAnchoredReferences>>;

      _state = _state.copyWith(
        status: ReaderStatus.ready,
        chapter: ChapterView(
          osisCode: osisCode,
          chapter: chapterNumber,
          verses: verses,
          startsAtVerse: verses.isEmpty ? 1 : verses.first.verse,
          crossReferences: references,
        ),
      );
    } on Object catch (e) {
      _state = _state.copyWith(status: ReaderStatus.failed, error: '$e');
    }
    notifyListeners();
  }

  /// The next chapter, or null at the end of the book.
  Future<void> next() async {
    final osis = _state.osisCode;
    final n = _state.chapterNumber;
    if (osis == null) return;
    final book = _state.book;
    if (book != null && n >= book.chapterCount) return;
    await show(osis, n + 1);
  }

  /// The previous chapter, or null at the start.
  Future<void> previous() async {
    final osis = _state.osisCode;
    final n = _state.chapterNumber;
    if (osis == null || n <= 1) return;
    await show(osis, n - 1);
  }

  Future<void> nextBook() async {
    final osis = _state.osisCode;
    if (osis == null || _state.books.isEmpty) return;
    final i = _state.books.indexWhere((b) => b.osisCode == osis);
    if (i < 0 || i + 1 >= _state.books.length) return;
    await show(_state.books[i + 1].osisCode, 1);
  }

  Future<void> previousBook() async {
    final osis = _state.osisCode;
    if (osis == null || _state.books.isEmpty) return;
    final i = _state.books.indexWhere((b) => b.osisCode == osis);
    if (i <= 0) return;
    await show(_state.books[i - 1].osisCode, 1);
  }

  /// Follows a cross-reference, remembering where the reader was.
  ///
  /// The target's book is checked against the module first. A reference to a book the
  /// module does not contain is still navigable — there may be another installed module
  /// that has it — but this reader cannot act on it, so it says so rather than appearing to
  /// do nothing.
  Future<void> followCrossReference(AmfCrossReference reference, {required String toBook}) async {
    await show(
      toBook,
      reference.toChapter,
      verse: reference.toVerse,
    );
  }

  /// Returns to the position before the last cross-reference.
  ///
  /// Pops rather than peeks, so going back twice returns to where the reader started. A
  /// peek would let the back control walk forward down a chain instead of unwinding it,
  /// which is the opposite of what "volver" means.
  Future<void> goBack() async {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    // Not pushed again: the position being returned to must not become a new entry, or the
    // history would grow while the reader walks back down it.
    await show(
      previous.osisCode,
      previous.chapter,
      verse: previous.verse,
      recordHistory: false,
    );
    _state = _state.copyWith(canGoBack: _history.isNotEmpty);
    notifyListeners();
  }

  /// Whether a cross-reference target is in a book this module has.
  bool canNavigateTo(String osisCode) =>
      _state.books.any((b) => b.osisCode == osisCode);

  // --- find ---

  /// Runs a find over the whole open module.
  ///
  /// The active match is seeded from where the reader already is, so opening the find bar
  /// and typing a word they can see lands them on that occurrence rather than the first one
  /// somewhere else in the Bible.
  Future<void> find(String term) async {
    final moduleId = _state.moduleId;
    final trimmed = term.trim();

    if (moduleId == null) {
      _state = _state.copyWith(
        find: const FindSession(term: ''),
        isFindBarVisible: false,
      );
      return;
    }
    if (trimmed.isEmpty) {
      // An emptied field clears the highlights rather than leaving them on a term the
      // reader has just deleted. The bar stays open, because they are still typing.
      _state = _state.copyWith(find: const FindSession(), isFindBarVisible: true);
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      find: FindSession(term: term, isSearching: true),
      isFindBarVisible: true,
    );
    notifyListeners();

    try {
      final result = await ModuleFinder(_repository).find(moduleId, trimmed);
      if (result.isEmpty) {
        _state = _state.copyWith(find: FindSession(term: term, result: result));
      } else {
        _state = _state.copyWith(
          find: FindSession(
            term: term,
            result: result,
            activeIndex: _nearestIndex(result),
          ),
        );
        await _reveal(_state.find.activeMatch);
      }
    } on Object catch (e) {
      // Reported in the bar rather than thrown: a find that fails is a find the user can
      // correct, not a reason for the reader to disappear.
      _state = _state.copyWith(
        find: FindSession(term: term, error: 'No se pudo buscar: $e'),
      );
    }
    notifyListeners();
  }

  /// Moves to the next match, wrapping to the first at the end.
  ///
  /// Wrapping because a find bar that stops at the last match leaves the reader unsure
  /// whether there is anything after it; the count already tells them how many there are,
  /// and wrapping makes that count usable as a loop.
  Future<void> nextMatch() => _step(1);

  /// Moves to the previous match, wrapping to the last at the beginning.
  Future<void> previousMatch() => _step(-1);

  Future<void> _step(int delta) async {
    final find = _state.find;
    final result = find.result;
    if (result == null || result.isEmpty) return;

    final next = (find.activeIndex + delta) % result.count;
    final moved = next < 0 ? result.count - 1 : next;

    _state = _state.copyWith(find: find.copyWith(activeIndex: moved));
    notifyListeners();
    await _reveal(result.matches[moved]);
  }

  /// The index of the match nearest the current position, so a find starts where the reader
  /// already is.
  int _nearestIndex(FindResult result) {
    final here = result.inChapter(_state.osisCode ?? '', _state.chapterNumber);
    if (here.isEmpty) return 0;
    final focus = _state.focusVerse;
    if (focus != null) {
      for (var i = 0; i < here.length; i++) {
        if (here[i].verse >= focus) return result.indexOf(here[i]);
      }
    }
    return result.indexOf(here.first);
  }

  /// Loads the chapter a match is in, if it is not the one already showing, and asks for it
  /// to be scrolled to.
  Future<void> _reveal(FindMatch? match) async {
    if (match == null) return;
    if (match.osisCode != _state.osisCode || match.chapter != _state.chapterNumber) {
      await show(match.osisCode, match.chapter, verse: match.verse);
    } else {
      _state = _state.copyWith(focusVerse: match.verse);
      notifyListeners();
    }
  }

  /// Shows or hides the find bar without running a search.
  ///
  /// Opening sets nothing else: an empty field with a field focus is the state the reader
  /// wants when they reach for the magnifier, and a search with an empty term would report
  /// "no matches" before they have typed a letter.
  void toggleFindBar() {
    _state = _state.copyWith(
      isFindBarVisible: !_state.isFindBarVisible,
      find: _state.isFindBarVisible ? const FindSession() : _state.find,
    );
    notifyListeners();
  }

  /// Clears the find bar and hides it.
  void closeFind() {
    _state = _state.copyWith(
      find: const FindSession(),
      isFindBarVisible: false,
    );
    notifyListeners();
  }

  void _pushHistory() {
    final osis = _state.osisCode;
    if (osis == null) return;
    // Not pushed when it would duplicate the current position, which happens when the
    // reader follows a reference into a passage it is already reading: unwinding that would
    // make the back control appear to do nothing.
    final position = ReaderPosition(
      osisCode: osis,
      chapter: _state.chapterNumber,
      verse: _state.focusVerse,
    );
    if (_history.isNotEmpty && _history.last == position) return;
    _history.add(position);
    if (_history.length > _historyLimit) _history.removeAt(0);
  }

  /// How many chapters in this module start at a verse other than 1.
  int get incompleteChapterCount => _state.integrity?.failures.length ?? 0;
}
