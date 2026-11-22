import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:betternotes/features/file_manager/file_manager_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:betternotes/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:betternotes/core/utils/pref_keys.dart';

import 'core/providers/global_providers.dart';
import 'package:betternotes/features/settings/settings.dart';

import 'package:betternotes/core/navigation/app_router.dart';

import 'core/providers/platform_notifier.dart';





/// Directories and route the app starts with. Loaded at startup and on every restart, so both
/// use the same fallbacks.
class StartupConfig {
  final String homeDir;
  final String currentDir;
  final String lastRoute;

  const StartupConfig({required this.homeDir, required this.currentDir, required this.lastRoute});
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

  return StartupConfig(
    homeDir: homeDir,
    currentDir: currentDir,
    lastRoute: prefs.getString(PrefKeys.lastRoute) ?? '/fileManager',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await loadStartupConfig();
  runApp(RestartWidget(initialConfig: config));
}

class MyApp extends ConsumerStatefulWidget {

  final String? initialRoute;
  const MyApp({super.key, this.initialRoute});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {

  late final GoRouter router;
  @override
  void initState() {
    super.initState();


    router = GoRouter(
      initialLocation: '/fileManager',
      routes: [
        GoRoute(path: '/fileManager', builder: (_, _) => const FileManager()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        //GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
      observers: [RouteSaver()],
    );

    // if necessary, push route after last frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      final lastRoute = widget.initialRoute ?? await loadLastRoute();

      if (lastRoute != null && lastRoute != '/fileManager') {
        unawaited(router.push(lastRoute));
      }
    });
  }


  @override
  Widget build(BuildContext context) {

    final settings = ref.watch(settingsProvider);

    ref.read(editorSetupProvider);
    return MaterialApp.router(
      routerConfig: router,

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

/// Root of the app. [restartApp] rebuilds everything below it, including a fresh ProviderScope
/// (used after theme changes).
class RestartWidget extends StatefulWidget {
  const RestartWidget({required this.initialConfig, super.key});
  final StartupConfig initialConfig;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();
  late StartupConfig _config = widget.initialConfig;

  Future<void> restartApp() async {
    final config = await loadStartupConfig();
    if (!mounted) return;
    setState(() {
      key = UniqueKey();        // enforces reinitialisation of all providers
      _config = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: ProviderScope(
        overrides: [
          platformProvider.overrideWith(() => PlatformSettingsNotifier(_config.homeDir, _config.currentDir)),
        ],
        child: MyApp(initialRoute: _config.lastRoute),
      ),
    );
  }
}
