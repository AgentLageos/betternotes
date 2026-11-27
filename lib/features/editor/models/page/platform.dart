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
