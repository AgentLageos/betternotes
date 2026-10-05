import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:betternotes/features/settings/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/global_providers.dart';




class SettingsNotifier extends Notifier<Settings> {


  int currentEditorID = 0;

  //String pathToFile = '/storage/emulated/0/betternotes/config.json';

  //File file = File('/storage/emulated/0/betternotes/config.json');

  late final dir = ref.read(platformProvider).homeDirectory;
  late File file = File('$dir/config/config.json');

  bool _loaded = false;

  @override
  Settings build() {
    _init();
    return Settings();
  }

  Future<void> _init() async {
    if (_loaded) return;
    _loaded = true;

    await loadSettings();
  }


  Future<void> setLanguage(String newLanguage) async {

    state = state.copyWith(language: Locale(newLanguage),);

    final config = await loadConfig();
    config['language'] = newLanguage;

    await file.writeAsString(
      jsonEncode(config),
      flush: true,
    );

    //print(state.language);
  }


  Future<void> setDarkMode(bool value) async {


    Brightness brightness = Brightness.light;
    if(value){
     brightness = Brightness.dark;
    }

    final colorScheme = ColorScheme(brightness: brightness, primary:darkModeSwitch(state.primary, value), onPrimary: darkModeSwitch(state.onPrimary, value), secondary: darkModeSwitch(state.secondary, value), onSecondary: darkModeSwitch(state.onSecondary, value), error: darkModeSwitch(state.error, value), onError: Colors.white, surface: darkModeSwitch(state.surface, value), onSurface: darkModeSwitch(state.onSurface, value));

    final config = await loadConfig();
    config['darkMode'] = value;
    config['primary'] = colorScheme.primary.value;
    config['onPrimary'] = colorScheme.onPrimary.value;
    config['surface'] = colorScheme.surface.value;
    config['onSurface'] = colorScheme.onSurface.value;
    config['secondary'] = colorScheme.secondary.value;
    config['onSecondary'] = colorScheme.onSecondary.value;

    await file.writeAsString(jsonEncode(config), flush: true,);

  }

  Future<void> setAccentColor(Color color) async {
    //print("accentcolor");

    Brightness brightness = Brightness.light;
    if(state.darkMode){
      brightness = Brightness.dark;
    }

    final seedScheme = ColorScheme.fromSeed(seedColor: color, brightness: brightness);
    final colorScheme = seedScheme.copyWith(primary: color);

    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setPrimaryColor(Color color) async {
    final colorScheme = ColorScheme(primary: color, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: state.onSecondary, surface: state.surface, onSurface: state.onSurface, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setOnPrimaryColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: color, secondary: state.secondary, onSecondary: state.onSecondary, surface: state.surface, onSurface: state.onSurface, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setSecondaryColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: color, onSecondary: state.onSecondary, surface: state.surface, onSurface: state.onSurface, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setOnSecondaryColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: color, surface: state.surface, onSurface: state.onSurface, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setSurfaceColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: state.onSecondary, surface: color, onSurface: state.onSurface, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setOnSurfaceColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: state.onSecondary, surface: state.surface, onSurface: color, error: state.error, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setErrorColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: state.onSecondary, surface: state.surface, onSurface: state.onSurface, error: color, onError: state.onError, brightness:  state.theme.brightness);
    //print(colorScheme.surface);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }

  Future<void> setOnErrorColor(Color color) async {
    final colorScheme = ColorScheme(primary: state.primary, onPrimary: state.onPrimary, secondary: state.secondary, onSecondary: state.onSecondary, surface: state.surface, onSurface: state.onSurface, error: state.error, onError: color, brightness:  state.theme.brightness);
    await writeColorsToConfig(state.darkMode, colorScheme);
  }



  Future<void> setDebugMode(bool value) async {
    state = state.copyWith(debugMode: value);
    final config = await loadConfig();
    config['debugMode'] = value;
    await file.writeAsString(jsonEncode(config), flush: true,);
  }



  Future<void> setColors({Color? primary, Color? onPrimary, Color? secondary, Color? onSecondary, Color? surface, Color? onSurface, Color? error, Color? onError, }) async {

    //await setDarkMode(false);

    if(primary == null) primary = state.primary;
    if(onPrimary == null) onPrimary = state.onPrimary;
    if(secondary == null) secondary = state.secondary;
    if(onSecondary == null) onSecondary = state.onSecondary;
    if(surface == null) surface = state.surface;
    if(onSurface == null) onSurface= state.onSurface;
    if(error == null) error = state.error;
    if(onError == null) onError = state.onError;

    final colorScheme = ColorScheme(primary: primary, onPrimary: onPrimary, secondary: secondary, onSecondary: onSecondary, surface: surface, onSurface: onSurface, error: error, onError: onError, brightness:  state.theme.brightness);
    await writeColorsToConfig(false, colorScheme);
  }







  Future<void> checkIfConfigFileExists() async {
    if (!await file.exists()) {
      print('couldn\'t find editor_setup.json');
      await generateConfig();
    }
  }


  Future<void> generateConfig() async {       //overwrites config file with default settings

    print("generate");

      //final file = File('/storage/emulated/0/betternotes/config.json');

      //print([...state].first.colorIndex);

      final jsonData = {
        'language': 'en',
        'showPageNumbers': true,
        'darkMode': false,
        'primary': Colors.blue.value,
        'primaryContainer': Colors.lightBlueAccent.shade100.value,
        'onPrimaryContainer': Colors.black87.value,
        "secondary":  Colors.blueAccent.value,
        'onSurface': Color(0xff333333).value,
        'surface': Colors.white.value,
        'onPrimary': Colors.black87.value,
        'onSecondary': Colors.white.value,
        'error': Colors.red.value,
        'onError': Colors.white.value,
        'debugMode': false,
      };

      try {
        final dir = file.parent;

        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        await file.writeAsString(
          jsonEncode(jsonData),
          flush: true,
        );

      } catch (e) {
        print("Error creating json: $e");
      }
    }


  Future<Map<String, dynamic>> loadConfig() async {
    await checkIfConfigFileExists();
    final String jsonString = await file.readAsString();
    return json.decode(jsonString);
  }

  Future<void> loadSettings() async {
    Map<String, dynamic> config = await loadConfig();

    try {
      setStateFromConfig(config);
    } catch (e, stackTrace) {
      print('Error loading config!: $e');
      print(stackTrace);
      print('Reseting Config...');

      await generateConfig();
      setStateFromConfig(config);




    }

    //print("settings loaded");
    //print(state.language);
  }


  void setStateFromConfig(Map<String, dynamic> config) {
    Brightness brightness = Brightness.light;
    if (config['darkMode'] == true) {
      brightness = Brightness.dark;
    }

    //print("setstate");
    //print(config['primary']);
    //print(brightness);
    //print(config['surface']);
    state = state.copyWith(
      language: Locale(config['language']),
      darkMode: config['darkMode'],
      primary: Color(config['primary']),
      primaryContainer: Color(config['primaryContainer']),
      onPrimaryContainer: Color(config['onPrimaryContainer']),
      secondary: Color(config['secondary']),
      onSurface: Color(config['onSurface']),
      surface: Color(config['surface']),
      onPrimary: Color(config['onPrimary']),
      onSecondary: Color(config['onSecondary']),
      error: Color(config['error']),
      onError: Color(config['onError']),
      debugMode: config['debugMode'],
      theme: ThemeData(colorScheme: ColorScheme(
        brightness: brightness,
        primary: Color(config['primary']),
        onPrimary: Color(config['onPrimary']),
        secondary: Color(config['secondary']),
        onSecondary: Color(config['onSecondary']),
        surface: Color(config['surface']),
        onSurface: Color(config['onSurface']),
        error: Color(config['error']),
        onError: Color(config['onError']),


      ),

      ),
    );

    //print(state.theme.colorScheme.primary);
  }

  Future<void> writeColorsToConfig(bool darkMode, ColorScheme colorScheme)async {
    final config = await loadConfig();
    config['darkMode'] = darkMode;
    config['primary'] = colorScheme.primary.value;
    config['onPrimary'] = colorScheme.onPrimary.value;
    config['surface'] = colorScheme.surface.value;
    config['onSurface'] = colorScheme.onSurface.value;
    config['secondary'] = colorScheme.secondary.value;
    config['onSecondary'] = colorScheme.onSecondary.value;
    config['error'] = colorScheme.error.value;
    config['onError'] = colorScheme.onError.value;

    await file.writeAsString(jsonEncode(config), flush: true,);

  }





  Color darkModeSwitch(Color color, bool darkMode) {
    final hsl = HSLColor.fromColor(color);
    double newLightness;
    if (darkMode) {newLightness = 1.0 - hsl.lightness;}
    else {newLightness = 1.0 - hsl.lightness;}
    newLightness = newLightness.clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
}