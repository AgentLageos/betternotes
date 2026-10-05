import 'dart:io';

import 'package:flutter/material.dart';
import 'package:betternotes/features/file_manager/file_manager_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:betternotes/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/global_providers.dart';
import 'package:betternotes/features/settings/settings.dart';

import 'package:betternotes/core/navigation/app_router.dart';

import 'core/navigation/navigator_state_notifier.dart';
import 'core/providers/platform_notifier.dart';





void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final appDocDir = await getApplicationDocumentsDirectory();

  final defaultHomeDir = appDocDir.path;
  final savedDir = prefs.getString('homeDirectory');
  final homeDir = savedDir ?? defaultHomeDir;

  if (savedDir == null) await prefs.setString('homeDirectory', homeDir);

  final defaultCurrentDir = '$homeDir/betternotes';
  final currentDir = prefs.getString('currentDirectory') ?? defaultCurrentDir;

  if (prefs.getString('currentDirectory') == null) {
    await prefs.setString('currentDirectory', currentDir);
  }

  await Directory(homeDir).create(recursive: true);
  await Directory(currentDir).create(recursive: true);

  runApp(
    RestartWidget(
      child: ProviderScope(
        overrides: [
          platformProvider.overrideWith(() => PlatformSettingsNotifier(homeDir, currentDir)),
        ],
        child: MyApp(),
      ),
    ),
  );
}





class MyApp extends ConsumerStatefulWidget {

  final String? initialRoute;
  const MyApp({super.key, this.initialRoute});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {

  late final GoRouter router;
  //late final settings = ref.watch(settingsProvider);
  @override
  void initState() {
    super.initState();


    router = GoRouter(
      initialLocation: '/fileManager',
      routes: [
        GoRoute(path: '/fileManager', builder: (_, __) => const FileManager()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        //GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
      observers: [RouteSaver()],
    );
    //print(router.configuration);

    // if necessary, push route after last frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      final lastRoute = widget.initialRoute ?? await loadLastRoute();

      if (lastRoute != null && lastRoute != '/fileManager') {
        router.push(lastRoute);
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



/*

to regenerate language files: flutter gen-l10n


 */

class RestartWidget extends StatefulWidget {
  const RestartWidget({required this.child, super.key});
  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();
  String? _lastRoute;
  String? _homeDir;
  String? currentDir;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    //load homedDir from shared prefs
    final prefs = await SharedPreferences.getInstance();
    final savedDir = prefs.getString('homeDirectory');
    //final savedDir = prefs.getString('currentDirectory');
    //print(savedDir);
    _homeDir = savedDir ?? (await getApplicationDocumentsDirectory()).path;

    currentDir = prefs.getString('currentDirectory') ?? '${(await getApplicationDocumentsDirectory()).path}/betternotes';
    //print(currentDir);
    if (prefs.getString('currentDirectory') == null) await prefs.setString('currentDirectory', _homeDir!);

    //_homeDir = (await getApplicationDocumentsDirectory()).path;

    //await prefs.setString('homeDirectory', _homeDir!);
    if (savedDir == null) await prefs.setString('homeDirectory', _homeDir!);

    //load last route
    setState(() {
      _lastRoute = prefs.getString('lastRoute') ?? '/fileManager';
    });
  }

  void restartApp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRoute = prefs.getString('lastRoute') ?? '/fileManager';
    currentDir = prefs.getString('currentDirectory') ?? '${(await getApplicationDocumentsDirectory()).path}/betternotes';
    if (prefs.getString('currentDirectory') == null) await prefs.setString('currentDirectory', _homeDir!);

    setState(() {
      key = UniqueKey();        // 🔹 enforces reinitialisation of all providers
      _lastRoute = lastRoute;   // re-sets route
      // _homeDir stays
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lastRoute == null || _homeDir == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return KeyedSubtree(
      key: key,
      child: ProviderScope(
        overrides: [// 🔹 reinitialize porvioder at every restart
          platformProvider.overrideWith(() => PlatformSettingsNotifier(_homeDir!, currentDir!)),
        ],
        child: MyApp(initialRoute: _lastRoute),
      ),
    );
  }
}