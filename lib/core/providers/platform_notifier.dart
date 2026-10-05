import 'dart:io';

import 'package:betternotes/features/editor/models/page/platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';




class PlatformSettingsNotifier extends Notifier<PlatformSettings> {
  final String homeDirectory;
  final String currentDirectory;

  PlatformSettingsNotifier(
      this.homeDirectory,
      this.currentDirectory
      );

  @override
  PlatformSettings build() {
    return PlatformSettings(homeDirectory: homeDirectory, currentDirectory: currentDirectory);
  }

  void setHomeDir(String dir) {
    state = state.copyWith(homeDirectory: dir);
    print("dir changed");
  }

  void setCurrentDir(String dir) {
    state = state.copyWith(currentDirectory: dir);
    //print("dir changed");
  }

  Future<void> changeHomeDir(String dir) async {
    state = state.copyWith(homeDirectory: dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homeDirectory', dir);

    print(dir);
    //await _requestPermission();


    final newState = state.copyWith(homeDirectory: dir);


    state = newState;
  }

  Future<void> setPrefs(PlatformSettings newState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_directory', newState.homeDirectory);
  }






}