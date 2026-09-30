/// A verse position, used to address scripture without a knowledge of versification.
class PassageRef implements Comparable<PassageRef> {
  const PassageRef(this.bookOsis, this.chapter, this.verse, {this.verseEnd});

  final String bookOsis;
  final int chapter;
  final int verse;

  /// Last verse of the range, when the reference spans more than one verse.
  final int? verseEnd;

  bool get isRange => verseEnd != null && verseEnd! > verse;

  @override
  int compareTo(PassageRef other) {
    final byBook = bookOsis.compareTo(other.bookOsis);
    if (byBook != 0) return byBook;
    final byChapter = chapter.compareTo(other.chapter);
    if (byChapter != 0) return byChapter;
    return verse.compareTo(other.verse);
  }

  @override
  bool operator ==(Object other) =>
      other is PassageRef &&
      other.bookOsis == bookOsis &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(bookOsis, chapter, verse, verseEnd);

  @override
  String toString() => '$bookOsis $chapter:$verse${isRange ? '-$verseEnd' : ''}';
}

/// Parses the reference syntax the search feature documents, e.g. `Jn 3:16`,
/// `Juan 3`, `1 Cor 13:4-7`.
class PassageRefParser {
  const PassageRefParser(this._aliases);

  /// Lower-cased OSIS code to accepted surface names.
  final Map<String, List<String>> _aliases;

  static final _pattern = RegExp(
    r'^\s*([1-3]?\s?[A-Za-záéíóúñÁÉÍÓÚÑ]+)\.?\s*(\d+)?\s*(?::\s*(\d+)\s*(?:-\s*(\d+))?)?\s*$',
  );

  /// Returns null when [raw] is not a reference at all.
  ///
  /// A reference with no verse yields [verse] 0, which is how "the whole chapter" is
  /// represented. Returning null there instead would make `Biblia:"Juan 3"` — one of the
  /// examples in the help panel — indistinguishable from a mistyped book name, and the
  /// user would be told a valid reference was invalid.
  PassageRef? tryParse(String raw) {
    final m = _pattern.firstMatch(raw);
    if (m == null) return null;

    final chapter = int.tryParse(m.group(2) ?? '');
    if (chapter == null) return null;

    final osis = _resolve(m.group(1)!);
    if (osis == null) return null;

    final verse = int.tryParse(m.group(3) ?? '') ?? 0;

    return PassageRef(osis, chapter, verse, verseEnd: int.tryParse(m.group(4) ?? ''));
  }

  /// True when [raw] names a book, even without chapter or verse.
  bool isBookReference(String raw) {
    final m = _pattern.firstMatch(raw);
    if (m == null) return false;
    return _resolve(m.group(1)!) != null && m.group(3) == null;
  }

  String? _resolve(String name) {
    final key = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    for (final entry in _aliases.entries) {
      if (entry.value.any((a) => a.toLowerCase().replaceAll(' ', '') == key)) {
        return entry.key;
      }
    }
    return null;
  }
}
