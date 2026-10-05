class PlatformSettings {
  final String homeDirectory;
  final String currentDirectory;

  const PlatformSettings({
    required this.homeDirectory,
    required this.currentDirectory,
  });

  PlatformSettings copyWith({
    String? homeDirectory,
    String? currentDirectory,
  }) {
    return PlatformSettings(
      homeDirectory: homeDirectory ?? this.homeDirectory,
      currentDirectory: currentDirectory ?? this.currentDirectory,
    );
  }
}

enum ColorPickerTab {
  normal,
  dotted,

}
extension ColorPickerTabExtension on ColorPickerTab {
  String toJson() => name;
  static ColorPickerTab fromJson(String value) => ColorPickerTab.values.firstWhere((e) => e.name == value);
}

class NavigationState {
  final String? homeDirectory;
  final String? currentDirectory;


  NavigationState({
    String? homeDirectory,
    String? currentDirectory,
  }) : homeDirectory = homeDirectory ?? homeDirectory,
        currentDirectory = currentDirectory ?? homeDirectory
  ;

  NavigationState copyWith({
    String? homeDirectory,
    String? currentDirectory,

  }) {
    return NavigationState(
      homeDirectory: homeDirectory ?? this.homeDirectory,
      currentDirectory: currentDirectory ?? this.currentDirectory,
    );
  }


}
