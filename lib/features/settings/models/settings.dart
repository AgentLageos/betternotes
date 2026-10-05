import 'dart:ui';
import 'package:flutter/material.dart';


class Settings {



  //general
  final Locale language;  //language of app
  final bool showPageNumbers; //displaying a number in he bottom right of pages, when enabled

  //Design
  final bool darkMode; //   0==auto; 1==bright; 2==dark

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color onSurface;
  final Color error;
  final Color onError;
  final ThemeData theme;
  final bool restartRequest;
  //final Color appColor; //color of onSurfaces, etc
  //final Color textColor; //color of text, buttons
  //final Color barColor; //color of top bars, highlighting






  //danger zone
  final bool debugMode; //when enabled shows additional information like grid of page-tiles and pageID





  Settings({
    bool? darkMode,
    Color? primary,
    Color? secondary,
    Color? onSurface,
    Color? surface,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? onSecondary,
    Color? error,
    Color? onError,
    Locale? language,
    bool? showPageNumbers,
    bool? debugMode,
    ThemeData? theme,
    bool? restartRequest,
  }) : darkMode = darkMode ?? false,
        primary = primary ?? Colors.brown,
        primaryContainer = primaryContainer ?? Colors.grey,
        onPrimaryContainer = onPrimaryContainer ?? Colors.grey,
        secondary = secondary ?? Colors.grey,
        onSurface = onSurface ?? Colors.white,
        surface = surface ?? Colors.white,
        onPrimary = onPrimary ?? Colors.black,
        onSecondary = onSecondary ?? Colors.deepPurpleAccent,
        error = error ?? Colors.red,
        onError = onError ?? Colors.white,
        language = language ?? const Locale('en'),
        showPageNumbers = showPageNumbers ?? true,
        debugMode = debugMode ?? false,
        theme = theme ?? ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue ,brightness: Brightness.light,)),
        restartRequest = restartRequest ?? false
  ;



  //selectorPools ?? [ToolSelector(tools: [0, 1, 2]), WidthSelector(widths: [0.4, 1.2, 4.0]), ColorSelector(colors: [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow])];

  Settings copyWith({
    bool? darkMode,
    Color? primary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSurface,
    Color? surface,
    Color? onPrimary,
    Color? onSecondary,
    Color? error,
    Color? onError,
    Locale? language,
    bool? showPageNumbers,
    bool? debugMode,
    ThemeData? theme,
    bool? restartRequest,


  }) {
    return Settings(
      darkMode: darkMode?? this.darkMode,
      primary: primary?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary?? this.secondary,
      onSurface: onSurface ?? this.onSurface,
      surface: surface ?? this.surface,
      onPrimary: onPrimary ?? this.onPrimary,
      onSecondary: onSecondary ?? this.onSecondary,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      language: language ?? this.language,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      debugMode: debugMode ?? this.debugMode,
      theme: theme ?? this.theme,
      restartRequest: restartRequest ?? this.restartRequest,

    );
  }
}