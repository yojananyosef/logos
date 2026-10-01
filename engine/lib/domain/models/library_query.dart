import 'package:flutter/foundation.dart';

import '../../data/repositories/library_repository.dart';
import 'catalog.dart';
import '../search/logos_text.dart';

/// Which half of the library the list is showing.
///
/// The reference offers exactly these two, as a segmented control, and they are a genuine
/// partition rather than two orderings: `Suyos` is what the user already has, `Tienda` is
/// what the catalog says they could get. A resource the user installed therefore appears
/// under one label and never the other, which is the property the segmented control
/// communicates and the reason it is not a sort.
enum LibraryScope {
  /// `Suyos` — everything installed, plus what the catalog records as theirs but that is
  /// still under copyright. Both are "yours" in the sense the control means: the user
  /// cannot acquire the second one and does not need to.
  mine('Suyos'),

  /// `Tienda` — everything installable: catalogued, and distributable today.
  store('Tienda');

  const LibraryScope(this.label);

  final String label;
}

/// How the list is ordered.
///
/// The reference shows `por Título` as a dropdown beside the segmented control, which is
/// the reason this is a sort and not a third scope: it changes the order of a list that is
/// already scoped, rather than which resources are in it.
enum LibrarySort {
  /// The catalog's own order. The default, and the only one that is not a comparison of
  /// strings.
  catalog('Catálogo'),

  /// `por Título` — alphabetical by title.
  title('por Título');

  const LibrarySort(this.label);

  final String label;
}

/// Grid or list.
enum LibraryViewMode {
  list('Lista'),
  grid('Cuadrícula');

  const LibraryViewMode(this.label);

  final String label;
}

/// Everything that narrows the library: the scope, the order, the text, and the layout.
///
/// A value rather than four fields on the ViewModel, because the four interact — a search
/// has to run against the sorted set, and the reported count has to describe the result of
/// both. Keeping them together makes "what the list shows" one thing with one answer, and
/// makes the count impossible to compute from a different set than the rows.
@immutable
class LibraryQuery {
  const LibraryQuery({
    this.scope = LibraryScope.mine,
    this.sort = LibrarySort.catalog,
    this.text = '',
    this.viewMode = LibraryViewMode.list,
  });

  final LibraryScope scope;
  final LibrarySort sort;

  /// The raw text as typed. Not folded here: the matcher folds both sides, and storing a
  /// folded copy would make it impossible to show the user what they typed back to them.
  final String text;

  final LibraryViewMode viewMode;

  /// Whether [text] would narrow anything.
  ///
  /// A query of only whitespace is treated as no query, because a trailing space is not a
  /// search term and treating it as one would empty the list as the user finishes typing.
  bool get hasText => text.trim().isNotEmpty;

  LibraryQuery copyWith({
    LibraryScope? scope,
    LibrarySort? sort,
    String? text,
    LibraryViewMode? viewMode,
  }) =>
      LibraryQuery(
        scope: scope ?? this.scope,
        sort: sort ?? this.sort,
        text: text ?? this.text,
        viewMode: viewMode ?? this.viewMode,
      );

  /// The entries this query selects from [entries], in order.
  ///
  /// Filtering and sorting are separate steps in that order, deliberately: sorting first
  /// would make the search's own comparison order decide the result, and the two orders
  /// disagree — `por Título` folds diacritics, the catalog order does not.
  List<LibraryEntry> apply(List<LibraryEntry> entries) {
    var out = entries.where(_inScope).toList();
    if (hasText) out = out.where(matchesText).toList();
    return _sorted(out);
  }

  bool _inScope(LibraryEntry entry) => switch (scope) {
        // Everything the user has, plus what they have been given the right to but which
        // the catalog still holds back. A resource that is installed *and* under copyright
        // appears once: installed wins, because the copy on disk is readable now and the
        // licence is about redistribution, not about reading.
        LibraryScope.mine => entry.installed || !entry.isDistributableNow(),
        LibraryScope.store => !entry.installed && entry.isDistributableNow(),
      };

  /// Whether [entry]'s title or subtitle contains the query.
  ///
  /// Both sides are folded, so `darby` finds `Darby` and `biblica` would find `Bíblica` —
  /// which matters here more than it does in scripture search, because the catalog holds
  /// accented titles in five languages and people type without the accents.
  bool matchesText(LibraryEntry entry) {
    final needle = LogosText.fold(text.trim());
    if (needle.isEmpty) return true;
    return LogosText.fold(resourceTitle(entry.resource)).contains(needle) ||
        LogosText.fold(resourceSubtitle(entry.resource)).contains(needle);
  }

  List<LibraryEntry> _sorted(List<LibraryEntry> entries) => switch (sort) {
        // The catalog's own order, which is the order the catalog file lists them in.
        // `List.where` preserves it, so this is a no-op that exists to make the switch
        // exhaustive rather than to re-sort something already ordered.
        LibrarySort.catalog => entries,
        LibrarySort.title => [...entries]..sort(_byTitle),
      };

  /// Alphabetical by title, folded.
  ///
  /// Folding is what makes the order readable rather than merely correct: an unaccented
  /// comparison puts `Éxodo` after every `Z`, because `É` is a higher code point than `Z`.
  /// The catalog holds German, French, Portuguese, Spanish, English, Greek and Hebrew, so
  /// that is not a hypothetical.
  ///
  /// Ties break on the raw title, so two resources whose folded titles collide — `Bible` and
  /// `Bíble` — still come out in a fixed order rather than in whatever order the previous
  /// filter happened to leave them.
  static int _byTitle(LibraryEntry a, LibraryEntry b) {
    final left = resourceTitle(a.resource);
    final right = resourceTitle(b.resource);
    final byFolded = LogosText.fold(left).compareTo(LogosText.fold(right));
    return byFolded != 0 ? byFolded : left.compareTo(right);
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.scope == scope &&
      other.sort == sort &&
      other.text == text &&
      other.viewMode == viewMode;

  @override
  int get hashCode => Object.hash(scope, sort, text, viewMode);

  @override
  String toString() =>
      'LibraryQuery(${scope.name}, ${sort.name}, "$text", ${viewMode.name})';
}

/// The title a resource is listed and searched under.
///
/// The name, falling back to the short name and then the id, so a catalog row missing
/// `name` still produces a row with a readable label rather than an empty one. The same
/// fallback chain is what `CatalogService` uses, so the two cannot disagree.
String resourceTitle(ResourceDescriptor resource) {
  for (final candidate in [resource.name, resource.shortName, resource.id]) {
    if (candidate.trim().isNotEmpty) return candidate.trim();
  }
  return '';
}

/// The line under a resource's title: its type, then who published it, then its genre.
///
/// One function rather than a format string in the view, because the search matches on this
/// same text — a subtitle assembled in two places is a subtitle that will eventually differ
/// between what the user reads and what the user searched, and the list would then filter
/// on words it never showed.
String resourceSubtitle(ResourceDescriptor resource) {
  final parts = <String>[resourceTypeLabel(resource.type)];
  for (final optional in [resource.publisher, resource.genre]) {
    if (optional != null && optional.trim().isNotEmpty) parts.add(optional.trim());
  }
  return parts.join(' · ');
}

/// The Spanish type label, as the reference spells it.
///
/// `Biblia` rather than `Biblia en inglés`: the reference's own subtitle is
/// `Biblia en inglés · Darby, John Nelson`, where the language word is a separate token
/// this catalog does not have a field for. Inventing one would put text in the list that
/// no catalog entry can justify, and the type alone still matches what the user types.
String resourceTypeLabel(ResourceType type) => switch (type) {
      ResourceType.bible => 'Biblia',
      ResourceType.commentary => 'Comentario bíblico',
      ResourceType.lexicon => 'Léxico',
      ResourceType.dictionary => 'Enciclopedia',
      ResourceType.crossref => 'Referencias cruzadas',
      ResourceType.devotion => 'Devocional',
      ResourceType.words => 'Palabras',
    };
