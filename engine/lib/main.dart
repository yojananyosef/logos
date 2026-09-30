import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_providers.dart';
import 'data/repositories/bible_repository.dart';
import 'data/services/module_installer.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved here, at the one place that is allowed to touch the platform channel, and
  // handed to the graph as a plain value. Views and ViewModels never learn where content
  // lives, which is what lets the tests swap in a temporary directory.
  final dir = await _resolveModuleDirectory();
  configureModulesDirectory(dir);

  // Learned before the first frame so that a reference typed as the very first thing the
  // user does resolves. See [configureBookAliases] for why this cannot be lazy.
  configureBookAliases(await BibleRepository(ModuleStore(dir)).bookAliases());

  runApp(const ProviderScope(child: LogosApp()));
}

Future<Directory> _resolveModuleDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/modules');
}
