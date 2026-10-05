import 'dart:convert';
import 'dart:io';

import 'package:betternotes/features/editor/models/page/platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';




class NavigatonStateNotifier extends Notifier<NavigationState> {


  @override
  NavigationState build() {
    return NavigationState();
  }

  void setHomeDir(String dir) {
    state = state.copyWith(homeDirectory: dir);
    print("dir changed");
  }

  Future<void> changeHomeDir(String dir) async {
    state = state.copyWith(homeDirectory: dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homeDirectory', dir);

    final newState = state.copyWith(homeDirectory: dir);

    state = newState;
  }

  Future<void> setPrefs(PlatformSettings newState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_directory', newState.homeDirectory);
  }


  Future<void> loadState() async {
    Map<String, dynamic> json = await loadJson();

    try {
      setStateFromJson(json);
    } catch (e, stackTrace) {
      print('Error loading config!: $e');
      print(stackTrace);
      print('Reseting Config...');

      await generateJson();
      setStateFromJson(json);

    }

  }


  Future<Map<String, dynamic>> loadJson() async {


    final dir = (await getApplicationDocumentsDirectory()).path;
    final file = File('$dir/config/navigator_state.json');

    if (!await file.exists()) {
      print('navigator_state.json nicht gefunden');
      await generateJson();
    }
    final String jsonString = await file.readAsString();
    return json.decode(jsonString);
  }

  Future<void> checkIfJsonExists(File file) async {
    if (!await file.exists()) {
      print('editor_setup.json nicht gefunden');
      await generateJson();
    }
  }

  Future<void> generateJson() async {       //overwrites config file with default settings

    final dir = (await getApplicationDocumentsDirectory()).path;
    final file = File('$dir/config/navigator_state.json');

    final jsonData = {
      'homeDirectory': dir+'/betternotes',
      'currentDirectory': dir+'/betternotes',
    };

    await file.writeAsString(
      jsonEncode(jsonData),
      flush: true,
    );
  }

  void setStateFromJson(Map<String, dynamic> config) {
    //print("setstate");
    state = state.copyWith(
      homeDirectory: config['homeDirectory'],
      currentDirectory: config['currentDirectory'],

    );

    //print(state.theme.colorScheme.primary);
  }






}