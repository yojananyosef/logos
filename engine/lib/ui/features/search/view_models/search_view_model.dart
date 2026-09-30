import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/search_repository.dart';
import '../../../../domain/models/passage_ref.dart';
import '../../../../domain/search/search_parser.dart';
import '../../../../domain/search/search_query.dart';

/// What the search screen is doing right now.
enum SearchStatus {
  /// Nothing typed yet. The syntax help panel is shown instead of results.
  idle,

  /// A query is being parsed or run.
  running,

  /// Results are on screen.
  ready,

  /// The query could not be parsed. The message names what is wrong.
  invalid,

  /// The query parsed and ran, and matched nothing.
  empty,
}

/// ViewModel for the search destination.
///
/// Holds the query text, the scope, and the outcome. It parses and runs; it never touches
/// SQLite or a file, because both live in [SearchRepository]. That separation is what lets
/// the whole state machine above be tested without a module on disk.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required this.repository,
    required this.referenceParser,
    SearchParser? parser,
  }) : _parser = parser ?? SearchParser(referenceParser.tryParse);

  final SearchRepository repository;
  final PassageRefParser referenceParser;
  final SearchParser _parser;

  String _query = '';
  String get query => _query;

  SearchScope _scope = SearchScope.all;
  SearchScope get scope => _scope;

  SearchStatus _status = SearchStatus.idle;
  SearchStatus get status => _status;

  SearchRun? _run;
  SearchRun? get run => _run;

  String? _error;
  String? get error => _error;

  /// The token the interface should underline, when the error names one.
  String? get errorOperator => _errorOperator;
  String? _errorOperator;

  /// The parsed query, exposed so the help panel can describe it.
  SearchNode? get parsed => _parsed;
  SearchNode? _parsed;

  /// Whether the syntax help panel should be shown in place of results.
  bool get showsHelp => _query.trim().isEmpty;

  /// Sets the query text and runs it.
  ///
  /// A query that does not parse leaves the text in place and reports the error. Clearing
  /// the field on a syntax error would be hostile: the user would lose what they typed
  /// while trying to fix it.
  void setQuery(String text) {
    _query = text;

    if (text.trim().isEmpty) {
      _status = SearchStatus.idle;
      _error = null;
      _errorOperator = null;
      _parsed = null;
      _run = null;
      notifyListeners();
      return;
    }

    try {
      _parsed = _parser.parse(text);
    } on SearchSyntaxException catch (e) {
      _status = SearchStatus.invalid;
      _error = e.message;
      _errorOperator = e.operator;
      _run = null;
      notifyListeners();
      return;
    }

    _error = null;
    _errorOperator = null;
    _status = SearchStatus.running;
    notifyListeners();
    unawaited(_runCurrent());
  }

  /// Runs the query again, e.g. after a scope change.
  ///
  /// Called rather than re-parsing so switching scope does not require retyping, which is
  /// the documented behaviour of the scope tabs.
  Future<void> refresh() async {
    if (_query.trim().isEmpty) return;
    try {
      _parsed = _parser.parse(_query);
    } on SearchSyntaxException catch (e) {
      _status = SearchStatus.invalid;
      _error = e.message;
      _errorOperator = e.operator;
      notifyListeners();
      return;
    }
    await _runCurrent();
  }

  /// Changes scope and re-runs the current query.
  Future<void> setScope(SearchScope scope) async {
    if (_scope == scope) return;
    _scope = scope;
    notifyListeners();
    await refresh();
  }

  Future<void> _runCurrent() async {
    final query = _parsed;
    if (query == null) return;
    try {
      final result = await repository.search(query, scope: _scope);
      _run = result;
      _status = result.isEmpty ? SearchStatus.empty : SearchStatus.ready;
    } on Object catch (e) {
      _status = SearchStatus.invalid;
      _error = '$e';
      _run = null;
    }
    notifyListeners();
  }

  /// Inserts an example from the help panel into the field and runs it.
  void runExample(String example) => setQuery(example);

  /// Clears the field and the results.
  void clear() => setQuery('');
}
