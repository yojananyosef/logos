import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextAlign;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../domain/models/reader_settings.dart';

/// Where reader settings are kept between sessions.
///
/// An interface rather than a `SharedPreferences` call at the point of use, because the
/// alternative makes the settings untestable without a platform channel: the reader's tests
/// would have to mock a plugin to assert that a text size survives a navigation, which is
/// testing the plugin rather than the reader.
abstract class ReaderPreferencesStore {
  /// The stored settings, or null when the reader has never been configured.
  Future<ReaderSettings?> read();

  Future<void> write(ReaderSettings settings);
}

/// Stores settings as one JSON string in shared preferences.
///
/// Written whole rather than field by field. The alternative is six keys that can be
/// individually absent — a partially-written record from an older version would leave the
/// reader with a text size from one session and a colour scheme from another, with nothing
/// to indicate that is not what was chosen.
class SharedPreferencesReaderStore implements ReaderPreferencesStore {
  const SharedPreferencesReaderStore(this._preferences);

  final SharedPreferences _preferences;

  static const String key = 'logos.reader.settings.v1';

  @override
  Future<ReaderSettings?> read() async {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ReaderSettings.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      // Corrupt rather than absent. Reported as "no stored settings" because that is what
      // the reader can act on: the alternative is refusing to open the reader over a
      // preference that only affects how text looks.
      return null;
    }
  }

  @override
  Future<void> write(ReaderSettings settings) =>
      _preferences.setString(key, jsonEncode(settings.toJson()));
}

/// Keeps settings in memory for the life of the process.
///
/// Used by tests and as the fallback when platform storage is unavailable, so a reader on a
/// platform where preferences cannot be opened still has a working `Formato` panel instead
/// of a disabled one.
class InMemoryReaderStore implements ReaderPreferencesStore {
  ReaderSettings? _settings;

  @override
  Future<ReaderSettings?> read() async => _settings;

  @override
  Future<void> write(ReaderSettings settings) async => _settings = settings;
}

/// Owns the reader's settings and tells listeners when they change.
///
/// A `ChangeNotifier` for the same reason every other ViewModel in this project is one:
/// the view reads a value and rebuilds when it changes, and nothing above this layer knows
/// that a text size is a thing that can be stored.
class ReaderPreferencesViewModel extends ChangeNotifier {
  ReaderPreferencesViewModel(this._store);

  final ReaderPreferencesStore _store;

  ReaderSettings _settings = const ReaderSettings();

  ReaderSettings get settings => _settings;

  /// Whether stored settings have been read yet.
  ///
  /// Separate from [settings] because the defaults are a legitimate value and a reader that
  /// has never stored anything is in exactly the same position as one whose stored
  /// preferences happen to be the defaults.
  bool get isLoaded => _loaded;
  bool _loaded = false;

  /// Reads stored settings. Called once at startup.
  ///
  /// A read failure is not surfaced: the reader works without it, and a storage error must
  /// not be the reason a Bible will not open. The fallback is the in-memory store's
  /// defaults, so the session still keeps whatever the user then chooses.
  Future<void> load() async {
    try {
      final stored = await _store.read();
      if (stored != null) _settings = stored;
    } on Object catch (e, s) {
      debugPrint('reader settings could not be read, using defaults: $e\n$s');
    }
    _loaded = true;
    notifyListeners();
  }

  void setVerseNumbers(VerseNumberStyle style) => _update(_settings.copyWith(verseNumbers: style));

  void setFont(ScriptureFont font) => _update(_settings.copyWith(font: font));

  void setTextSize(TextSizeStep size) => _update(_settings.copyWith(textSize: size));

  void setLineSpacing(LineSpacing spacing) => _update(_settings.copyWith(lineSpacing: spacing));

  void setColourScheme(ReadingColourScheme scheme) =>
      _update(_settings.copyWith(colourScheme: scheme));

  void setAlignment(TextAlignValue alignment) =>
      _update(_settings.copyWith(alignment: alignment.value));

  /// Restores every setting to its default.
  ///
  /// Exists because a reader who has moved the text size to the largest step and cannot
  /// find the control again is stuck: the text is too large to read the `Formato` label that
  /// would undo it. This is the documented way out, and it is reachable from the panel.
  void reset() => _update(const ReaderSettings());

  void _update(ReaderSettings next) {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    // Fire-and-forget: a failed write costs the next session its preference, and blocking
    // the UI on storage would make changing a text size feel like saving a document.
    _store.write(next).catchError(
      (Object e) => debugPrint('reader settings could not be written: $e'),
    );
  }
}

/// The three alignments the format panel offers.
///
/// Wrapped rather than exposing `TextAlign` directly so the panel cannot offer `left` and
/// `right` as separate choices in a right-to-left module, where they are the same edge.
enum TextAlignValue {
  start(TextAlign.start, 'Al inicio'),
  justify(TextAlign.justify, 'Justificado');

  const TextAlignValue(this.value, this.label);

  final TextAlign value;
  final String label;
}
