import 'package:shared_preferences/shared_preferences.dart';

import '../../../../domain/models/library_query.dart';

/// Where the library's view mode is kept between sessions.
///
/// An interface for the same reason the reader's is: the requirement is that a chosen view
/// mode survives *leaving the resource*, and only a store that still has the value after
/// everything holding it has been discarded can demonstrate that. Asserting it through an
/// in-memory fake would pass whether or not the key was ever written.
abstract class LibraryViewPreferencesStore {
  Future<LibraryViewMode?> read();

  Future<void> write(LibraryViewMode mode);
}

/// Stores the view mode in shared preferences.
///
/// A single key holding the enum's *name* rather than its index. An index would be one
/// character cheaper and would silently reinterpret every user's stored choice if the enum
/// ever gained or lost a value — `grid` becoming the third member would turn everyone's
/// grid into whatever used to be third. A name that is no longer recognised falls back to
/// the default, which is a lost preference rather than a wrong one.
class SharedPreferencesLibraryViewStore implements LibraryViewPreferencesStore {
  const SharedPreferencesLibraryViewStore(this._preferences);

  final SharedPreferences _preferences;

  static const String key = 'logos.library.viewMode.v1';

  @override
  Future<LibraryViewMode?> read() async {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    for (final mode in LibraryViewMode.values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }

  @override
  Future<void> write(LibraryViewMode mode) => _preferences.setString(key, mode.name);
}

/// Keeps the view mode in memory for the life of the process.
///
/// The fallback when platform storage cannot be opened, so a library on a platform where
/// preferences are unavailable still switches view modes — for this session.
class InMemoryLibraryViewStore implements LibraryViewPreferencesStore {
  LibraryViewMode? _mode;

  @override
  Future<LibraryViewMode?> read() async => _mode;

  @override
  Future<void> write(LibraryViewMode mode) async => _mode = mode;
}
