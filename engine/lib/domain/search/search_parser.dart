import '../models/passage_ref.dart';
import 'logos_text.dart';
import 'search_query.dart';

/// Turns a query string into a [SearchNode].
///
/// Precedence, tightest first: `DENTRO` distance forms, then `CERCA`, then the ordering
/// operators, then `NO`, then `Y`, then `O`. The shape constraints bind first because they
/// are the most specific thing a user can say, and the broadest disjunction binds last
/// because `O` is the one that most easily turns a whole query into "either of these".
///
/// The ladder is what makes `A O B CERCA C` mean `(A O B) CERCA C` rather than
/// `A O (B CERCA C)`, and it is the reading a person writing the query would expect.
class SearchParser {
  SearchParser(this._referenceParser);

  /// Resolves the book names in a reference. Injected so book aliases are not duplicated
  /// between the query language and the reader.
  final ReferenceResolver _referenceParser;

  /// Parses [query], throwing [SearchSyntaxException] if it cannot be understood.
  SearchNode parse(String query) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) {
      throw const SearchSyntaxException('La búsqueda está vacía.');
    }
    final cursor = _Cursor(tokens);
    final node = _parseOr(cursor);
    if (cursor.hasMore) {
      final token = cursor.peek()!;
      // A leftover operator word is almost always a mistyped operator: `Cristo CERKCA
      // Jesús` parses `Cristo`, stops at `CERKCA`, and reports it here. Saying "unexpected
      // token" instead would leave the user with no idea which word to correct.
      if (token.kind == _TokenKind.operatorWord) {
        cursor.consumeOperatorWord();
      }
      // A closing parenthesis is always a mismatch, and saying so is more useful than
      // naming it unexpected: `a) O b` has a bracket the user can see and delete.
      if (token.kind == _TokenKind.rightParen) {
        throw SearchSyntaxException(
          'Hay un paréntesis de cierre sin abrir en la posición ${token.start + 1}.',
          position: token.start,
        );
      }
      throw SearchSyntaxException(
        'No se esperaba «${token.text}» en la posición ${token.start + 1}.',
        position: token.start,
      );
    }
    return node;
  }

  /// Parses [query], returning null instead of throwing.
  ///
  /// Used where a half-typed query is normal — the field is parsed as the user types, and
  /// a syntax error mid-word should not clear the field.
  SearchNode? tryParse(String query) {
    try {
      return parse(query);
    } on SearchSyntaxException {
      return null;
    }
  }

  // --- Precedence ladder -----------------------------------------------------------

  SearchNode _parseOr(_Cursor c) {
    var left = _parseAnd(c);
    while (c.consumeKeyword(SearchOperator.either)) {
      final right = _parseAnd(c);
      left = SearchBinary(SearchOperator.either, left, right);
    }
    return left;
  }

  SearchNode _parseAnd(_Cursor c) {
    var left = _parseNot(c);
    while (true) {
      if (c.consumeKeyword(SearchOperator.both)) {
        left = SearchBinary(SearchOperator.both, left, _parseNot(c));
        continue;
      }
      // Two words side by side mean both, which is the rule the help panel states: it
      // lists `Cristo Jesús` beside `Cristo Y Jesús` as the same query. Without this, a
      // bare multi-word search — the most ordinary thing a user types — would be a syntax
      // error.
      if (c.startsOperand) {
        left = SearchBinary(SearchOperator.both, left, _parseNot(c));
        continue;
      }
      return left;
    }
  }

  SearchNode _parseNot(_Cursor c) {
    final left = _parseOrdered(c);
    while (c.consumeKeyword(SearchOperator.excluding)) {
      final right = _parseOrdered(c);
      return SearchBinary(SearchOperator.excluding, left, right);
    }
    return left;
  }

  SearchNode _parseOrdered(_Cursor c) {
    var left = _parseNear(c);
    while (true) {
      final token = c.peekOperator({SearchOperator.before, SearchOperator.after});
      if (token == null) return left;
      c.advance();
      final op = SearchOperator.tryParse(token.text);
      if (op == null) return left;
      final right = _parseNear(c);
      left = SearchBinary(op, left, right);
    }
  }

  SearchNode _parseNear(_Cursor c) {
    var left = _parseWithin(c);
    while (true) {
      final op = c.peekOperator({SearchOperator.near});
      if (op == null) return left;
      c.advance();
      // The help panel shows both `Cristo CERCA Jesús` and `Cristo CERCA 5 Jesús`, so the
      // distance is optional and defaults when absent.
      var distance = SearchOperator.defaultDistance;
      final number = c.consumeNumber();
      if (number != null) {
        if (number < 0) {
          throw SearchSyntaxException('La distancia no puede ser negativa: $number.');
        }
        distance = number;
      }
      final right = _parseWithin(c);
      left = SearchBinary(SearchOperator.near, left, right, distance: distance);
    }
  }

  SearchNode _parseWithin(_Cursor c) {
    var left = _parsePrimary(c);
    while (true) {
      if (!c.peekKeyword(SearchOperator.withinWords)) return left;
      c.advance();
      final count = c.consumeNumber();
      if (count == null) {
        throw const SearchSyntaxException(
          'DENTRO necesita un número: use «DENTRO 5 PALABRAS» o «DENTRO 20 CARACT».',
          operator: 'DENTRO',
        );
      }
      // PALABRAS and CARACT are the two units and are required. Inferring the unit would
      // let a typo silently search the wrong distance, so an unrecognised one is
      // reported. Consumed as a plain token rather than through the operator path,
      // because `PALABRAS` is a unit and not a mistyped operator.
      final unit = c.next();
      final upper = LogosText.fold(unit?.text ?? '').toUpperCase();
      final isChars = upper.startsWith('CARACT');
      final isWords = upper.startsWith('PALABRAS');
      if (unit == null || (!isChars && !isWords)) {
        throw SearchSyntaxException(
          'DENTRO $count necesita una unidad: PALABRAS o CARACT, no «${unit?.text ?? ''}».',
          operator: 'DENTRO',
        );
      }
      final right = _parsePrimary(c);
      left = SearchBinary(
        isChars ? SearchOperator.withinChars : SearchOperator.withinWords,
        left,
        right,
        distance: count,
      );
    }
  }

  SearchNode _parsePrimary(_Cursor c) {
    final token = c.next();
    if (token == null) {
      throw const SearchSyntaxException('La búsqueda termina de forma inesperada.');
    }
    switch (token.kind) {
      case _TokenKind.term:
        return SearchTerm(token.text);
      case _TokenKind.phrase:
        return SearchPhrase(token.text);
      case _TokenKind.reference:
        return _reference(token);
      case _TokenKind.operatorWord:
        // An all-caps word where an operand belongs is only a mistake if something
        // follows it. `CERKCA` in `Cristo CERKCA Jesús` is a mistyped operator and has to
        // be reported; a lone `BIBLIA` is somebody searching for a title and has to stay
        // searchable. The distinction is whether an operand is still expected.
        if (c.hasMore && c.startsOperand) {
          c.consumeOperatorWord();
          throw SearchSyntaxException(
            '«${token.text}» no es un operador de búsqueda válido.',
            operator: token.text,
            position: token.start,
          );
        }
        return SearchTerm(token.text);
      case _TokenKind.leftParen:
        final inner = _parseOr(c);
        if (!c.consumeRightParen()) {
          throw SearchSyntaxException(
            'Falta el cierre de paréntesis abierto en la posición ${token.start + 1}.',
            position: token.start,
          );
        }
        return SearchGroup(inner);
      case _TokenKind.rightParen:
        throw SearchSyntaxException(
          'Hay un paréntesis de cierre sin abrir en la posición ${token.start + 1}.',
          position: token.start,
        );
    }
  }

  SearchNode _reference(_Token token) {
    final resolved = _referenceParser(token.text);
    if (resolved == null) {
      throw SearchSyntaxException(
        'La referencia «${token.text}» no es válida. Ejemplo: Biblia:"Jn 3:16".',
        position: token.start,
      );
    }
    return SearchReference(resolved, exact: token.exact);
  }

  // --- Tokenizer -------------------------------------------------------------------

  static final _referencePattern =
      RegExp(r'^\s*Biblia\s*:\s*(=?)\s*"([^"]*)"\s*$', caseSensitive: false);

  List<_Token> _tokenize(String query) {
    final tokens = <_Token>[];
    var i = 0;
    while (i < query.length) {
      final ch = query[i];

      if (ch.trim().isEmpty) {
        i++;
        continue;
      }

      if (ch == '(') {
        tokens.add(_Token(_TokenKind.leftParen, '(', i));
        i++;
        continue;
      }
      if (ch == ')') {
        tokens.add(_Token(_TokenKind.rightParen, ')', i));
        i++;
        continue;
      }
      if (ch == '"') {
        final end = query.indexOf('"', i + 1);
        if (end < 0) {
          throw SearchSyntaxException(
            'Falta la comilla de cierre abierta en la posición ${i + 1}.',
            position: i,
          );
        }
        tokens.add(_Token(_TokenKind.phrase, query.substring(i + 1, end), i));
        i = end + 1;
        continue;
      }

      // A reference is recognised only in the `Biblia:"..."` form, with the quotes. A bare
      // `Biblia` is the ordinary Spanish word for the Bible and stays searchable, which is
      // why the prefix alone is not enough to trigger this branch.
      final reference = _referencePattern.matchAsPrefix(query.substring(i));
      if (reference != null) {
        tokens.add(
          _Token(
            _TokenKind.reference,
            reference.group(2)!,
            i,
            exact: reference.group(1) == '=',
          ),
        );
        i += reference.end;
        continue;
      }

      // A sign belongs to the number that follows it, so `CERCA -5` is a distance of
      // minus five rather than a distance followed by a stray operator.
      if (ch == '-' || ch == '+') {
        final after = i + 1;
        if (after < query.length && RegExp(r'^[0-9]').hasMatch(query[after])) {
          final digits = _readWord(query, after);
          tokens.add(_Token(_TokenKind.term, '$ch${digits.text}', i));
          i = digits.end;
          continue;
        }
      }

      final word = _readWord(query, i);
      if (word.text.isEmpty) {
        // A character that is not whitespace, a bracket or a quote: skip it rather than
        // failing, so a stray symbol does not make the whole query unusable.
        i++;
        continue;
      }
      i = word.end;
      tokens.add(
        _Token(
          word.text == word.text.toUpperCase() && _hasLetters(word.text)
              ? _TokenKind.operatorWord
              : _TokenKind.term,
          word.text,
          word.start,
        ),
      );
    }
    return tokens;
  }

  /// Reads a bare word, stopping at whitespace, quotes and brackets.
  ///
  /// A word may not be split at a bracket because `Biblia` and `"Jn 3:16"` have to stay
  /// adjacent for the reference form to be seen, and they are separated by `:` and `"`,
  /// neither of which is a bracket.
  ({String text, int start, int end}) _readWord(String query, int from) {
    final start = from;
    var i = from;
    while (i < query.length) {
      final ch = query[i];
      if (ch.trim().isEmpty || ch == '"' || ch == '(' || ch == ')') break;
      i++;
    }
    return (text: query.substring(start, i), start: start, end: i);
  }

  static bool _hasLetters(String s) => s.codeUnits
      .any((u) => (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || u >= 0xC0);
}

// --- Cursor ----------------------------------------------------------------------

/// Walks the token list, and is the only place that knows an unknown operator is an
/// error.
///
/// An all-caps word that is not a known operator is reported rather than searched for.
/// A user who mistypes `CERKCA` would otherwise get an empty result set and no way to
/// tell the query was wrong from the corpus being silent — which is the difference
/// between a fixable mistake and a dead end. Only all-caps words are treated this way,
/// so a lowercase word that happens to be `despues` is still just a word.
class _Cursor {
  _Cursor(this.tokens);

  final List<_Token> tokens;
  int _index = 0;

  bool get hasMore => _index < tokens.length;

  _Token? peek() => _index < tokens.length ? tokens[_index] : null;

  /// Whether the next token can begin an operand.
  ///
  /// Used to spot the implicit AND between two adjacent words. An operator word does not
  /// count: `a O b` is a disjunction, not a conjunction of `a` with the word `O`.
  bool get startsOperand {
    final t = peek();
    if (t == null) return false;
    return t.kind == _TokenKind.term ||
        t.kind == _TokenKind.phrase ||
        t.kind == _TokenKind.reference ||
        t.kind == _TokenKind.leftParen;
  }

  _Token? advance() => _index < tokens.length ? tokens[_index++] : null;

  _Token? next() => advance();

  bool consumeRightParen() {
    final t = peek();
    if (t != null && t.kind == _TokenKind.rightParen) {
      _index++;
      return true;
    }
    return false;
  }

  bool peekKeyword(SearchOperator op) {
    final t = peek();
    if (t == null || t.kind != _TokenKind.operatorWord) return false;
    return SearchOperator.tryParse(t.text) == op;
  }

  _Token? peekOperator(Set<SearchOperator> ops) {
    final t = peek();
    if (t == null || t.kind != _TokenKind.operatorWord) return null;
    final op = SearchOperator.tryParse(t.text);
    return op != null && ops.contains(op) ? t : null;
  }

  /// Consumes a keyword if the next token is it.
  bool consumeKeyword(SearchOperator op) {
    if (!peekKeyword(op)) return false;
    _index++;
    return true;
  }

  /// Consumes the keyword at the cursor and requires it to be a known operator.
  ///
  /// Throws naming the token, which is what the interface shows under the field.
  _Token? consumeOperatorWord() {
    final t = peek();
    if (t == null || t.kind != _TokenKind.operatorWord) return null;
    _index++;
    if (SearchOperator.tryParse(t.text) == null) {
      throw SearchSyntaxException(
        '«${t.text}» no es un operador de búsqueda válido.',
        operator: t.text,
        position: t.start,
      );
    }
    return t;
  }

  /// Consumes an optionally signed integer.
  ///
  /// The sign is accepted here rather than at each call site so `CERCA -5` and
  /// `DENTRO -2 PALABRAS` are each seen as the single token they are, and rejected as
  /// negative in one place. Without the sign in the pattern, `-5` fails to match, is left
  /// on the stream, and becomes a third operand the implicit-AND rule then folds in — so
  /// `a CERCA -5 b` would quietly parse as `(a CERCA) Y -5 Y b` with no distance at all.
  int? consumeNumber() {
    final t = peek();
    if (t == null || !RegExp(r'^[+-]?\d+$').hasMatch(t.text)) return null;
    _index++;
    return int.tryParse(t.text);
  }
}

enum _TokenKind { term, phrase, reference, operatorWord, leftParen, rightParen }

class _Token {
  const _Token(this.kind, this.text, this.start, {this.exact = false});

  final _TokenKind kind;
  final String text;
  final int start;

  /// True for the `Biblia:=` form.
  final bool exact;
}

/// Resolves a reference's text to a position in a module.
///
/// Returning null means "not a reference this module has", which the parser turns into a
/// message naming the text the user typed. Injected so the book-alias table lives with
/// the reader rather than being duplicated here.
typedef ReferenceResolver = PassageRef? Function(String text);
