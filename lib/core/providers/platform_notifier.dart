
import 'package:betternotes/features/editor/models/page/platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betternotes/core/utils/pref_keys.dart';




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
  }

  Future<void> changeHomeDir(String dir) async {
    state = state.copyWith(homeDirectory: dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.homeDirectory, dir);

    print(dir);


    final newState = state.copyWith(homeDirectory: dir);


    state = newState;
  }







}