import 'dart:io';

import 'package:flutter/material.dart';
import 'package:betternotes/features/file_manager/file_manager_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:betternotes/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:betternotes/core/utils/pref_keys.dart';

import 'core/providers/global_providers.dart';


import 'core/providers/platform_notifier.dart';





/// Directories the app starts with.
class StartupConfig {
  final String homeDir;
  final String currentDir;

  const StartupConfig({required this.homeDir, required this.currentDir});
}

Future<StartupConfig> loadStartupConfig() async {
  final prefs = await SharedPreferences.getInstance();

  final homeDir = prefs.getString(PrefKeys.homeDirectory)
      ?? (await getApplicationDocumentsDirectory()).path;
  final currentDir = prefs.getString(PrefKeys.currentDirectory)
      ?? p.join(homeDir, 'betternotes');

  await prefs.setString(PrefKeys.homeDirectory, homeDir);
  await prefs.setString(PrefKeys.currentDirectory, currentDir);

  await Directory(homeDir).create(recursive: true);
  await Directory(currentDir).create(recursive: true);

  return StartupConfig(homeDir: homeDir, currentDir: currentDir);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await loadStartupConfig();
  runApp(
    ProviderScope(
      overrides: [
        platformProvider.overrideWith(() => PlatformSettingsNotifier(config.homeDir, config.currentDir)),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root widget. Theme and language come from [settingsProvider] and change live.
/// Navigation: plain [Navigator] everywhere (P4-05); the file manager is the start screen.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    ref.read(editorSetupProvider);
    return MaterialApp(
      home: const FileManager(),
      locale: settings.language,
      theme: settings.theme,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

// To regenerate the language files: flutter gen-l10n
