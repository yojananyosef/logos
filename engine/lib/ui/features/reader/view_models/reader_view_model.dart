import 'package:flutter/foundation.dart';

import '../../../../data/repositories/bible_repository.dart';
import '../../../../data/services/amf_reader.dart';

/// A chapter as the reader presents it.
class ChapterView {
  const ChapterView({
    required this.osisCode,
    required this.chapter,
    required this.verses,
    required this.startsAtVerse,
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

  /// The chapter is missing its first verse.
  bool get isIncomplete => startsAtVerse != 1;
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
  });

  final String? moduleId;
  final ReaderStatus status;
  final List<AmfBook> books;
  final String? osisCode;
  final int chapterNumber;
  final ChapterView? chapter;
  final String? error;
  final IntegrityReport? integrity;

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
      );
}

/// ViewModel for the Bible reader.
///
/// Owns which book and chapter are open and nothing else: the verses come from the
/// repository, and no SQL or file access happens here.
class ReaderViewModel extends ChangeNotifier {
  ReaderViewModel(this._repository);

  final BibleRepository _repository;

  ReaderState _state = const ReaderState();
  ReaderState get state => _state;

  /// Opens a module and shows its first book.
  Future<void> open(String moduleId, {String? osisCode, int chapter = 1}) async {
    _state = ReaderState(moduleId: moduleId, status: ReaderStatus.loading);
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
  Future<void> show(String osisCode, int chapterNumber) async {
    final moduleId = _state.moduleId;
    if (moduleId == null) return;

    _state = _state.copyWith(
      status: ReaderStatus.loading,
      osisCode: osisCode,
      chapterNumber: chapterNumber,
      clearError: true,
    );
    notifyListeners();

    try {
      final verses = await _repository.chapter(moduleId, osisCode, chapterNumber);
      _state = _state.copyWith(
        status: ReaderStatus.ready,
        chapter: ChapterView(
          osisCode: osisCode,
          chapter: chapterNumber,
          verses: verses,
          startsAtVerse: verses.isEmpty ? 1 : verses.first.verse,
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

  /// How many chapters in this module start at a verse other than 1.
  int get incompleteChapterCount => _state.integrity?.failures.length ?? 0;
}
