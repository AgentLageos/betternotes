import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'File Manager'**
  String get title;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @design.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get design;

  /// No description provided for @danger_zone.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get danger_zone;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @accent_color.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accent_color;

  /// No description provided for @advanced_color_settings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Color Settings'**
  String get advanced_color_settings;

  /// No description provided for @primary_color.
  ///
  /// In en, this message translates to:
  /// **'Primary Color'**
  String get primary_color;

  /// No description provided for @on_primary_color.
  ///
  /// In en, this message translates to:
  /// **'On Top Primary Color'**
  String get on_primary_color;

  /// No description provided for @primary_color_containers.
  ///
  /// In en, this message translates to:
  /// **'Primary Color Containers'**
  String get primary_color_containers;

  /// No description provided for @on_primary_color_containers.
  ///
  /// In en, this message translates to:
  /// **'On Top Primary Color Containers'**
  String get on_primary_color_containers;

  /// No description provided for @secondary_color.
  ///
  /// In en, this message translates to:
  /// **'Secondary Color'**
  String get secondary_color;

  /// No description provided for @on_secondary_color.
  ///
  /// In en, this message translates to:
  /// **'On Top Secondary Color'**
  String get on_secondary_color;

  /// No description provided for @surface_color.
  ///
  /// In en, this message translates to:
  /// **'Surface Color'**
  String get surface_color;

  /// No description provided for @on_surface_color.
  ///
  /// In en, this message translates to:
  /// **'On Top Surface Color'**
  String get on_surface_color;

  /// No description provided for @error_color.
  ///
  /// In en, this message translates to:
  /// **'Error Color'**
  String get error_color;

  /// No description provided for @on_error_color.
  ///
  /// In en, this message translates to:
  /// **'on_error_color'**
  String get on_error_color;

  /// No description provided for @changing_accent_color.
  ///
  /// In en, this message translates to:
  /// **'Changing the Accent Color will overwrite Advanced Color Settings'**
  String get changing_accent_color;

  /// No description provided for @color_themes.
  ///
  /// In en, this message translates to:
  /// **'Color Themes'**
  String get color_themes;

  /// No description provided for @enter_matrix.
  ///
  /// In en, this message translates to:
  /// **'Enter Matrix'**
  String get enter_matrix;

  /// No description provided for @relaxing_blue.
  ///
  /// In en, this message translates to:
  /// **'Relaxing Blue'**
  String get relaxing_blue;

  /// No description provided for @retrowave.
  ///
  /// In en, this message translates to:
  /// **'Retrowave'**
  String get retrowave;

  /// No description provided for @excellence.
  ///
  /// In en, this message translates to:
  /// **'Excellence'**
  String get excellence;

  /// No description provided for @kernel.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get kernel;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @customize_tools.
  ///
  /// In en, this message translates to:
  /// **'Customize Tools'**
  String get customize_tools;

  /// No description provided for @number_of_widths.
  ///
  /// In en, this message translates to:
  /// **'Number of Penwidths'**
  String get number_of_widths;

  /// No description provided for @number_of_colors.
  ///
  /// In en, this message translates to:
  /// **'Number of Colors'**
  String get number_of_colors;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @widths.
  ///
  /// In en, this message translates to:
  /// **'Widths'**
  String get widths;

  /// No description provided for @colors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colors;

  /// No description provided for @undo_redo.
  ///
  /// In en, this message translates to:
  /// **'Undo/Redo'**
  String get undo_redo;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @default_page_setup.
  ///
  /// In en, this message translates to:
  /// **'Default Page Setup'**
  String get default_page_setup;

  /// No description provided for @page_height.
  ///
  /// In en, this message translates to:
  /// **'Page Height'**
  String get page_height;

  /// No description provided for @page_width.
  ///
  /// In en, this message translates to:
  /// **'Page Width'**
  String get page_width;

  /// No description provided for @page_size_presets.
  ///
  /// In en, this message translates to:
  /// **'Page Size Presets'**
  String get page_size_presets;

  /// No description provided for @portrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portrait;

  /// No description provided for @landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscape;

  /// No description provided for @page_color.
  ///
  /// In en, this message translates to:
  /// **'Page Color'**
  String get page_color;

  /// No description provided for @vertical_space.
  ///
  /// In en, this message translates to:
  /// **'Vertical Spaces'**
  String get vertical_space;

  /// No description provided for @horizontal_space.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Spaces'**
  String get horizontal_space;

  /// No description provided for @background_lines_width.
  ///
  /// In en, this message translates to:
  /// **'Background Lines Width'**
  String get background_lines_width;

  /// No description provided for @background_lines_color.
  ///
  /// In en, this message translates to:
  /// **'Background Lines Color'**
  String get background_lines_color;

  /// No description provided for @debug_mode.
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get debug_mode;

  /// No description provided for @manage_app_permissions.
  ///
  /// In en, this message translates to:
  /// **'Manage App Permissions'**
  String get manage_app_permissions;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @app_version.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get app_version;

  /// No description provided for @build_number.
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get build_number;

  /// No description provided for @developed_by.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get developed_by;

  /// No description provided for @open_source_licenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get open_source_licenses;

  /// No description provided for @view_licenses_of_used_libraries.
  ///
  /// In en, this message translates to:
  /// **'View licenses of used libraries'**
  String get view_licenses_of_used_libraries;

  /// No description provided for @new_directory.
  ///
  /// In en, this message translates to:
  /// **'New Directory'**
  String get new_directory;

  /// No description provided for @create_new_directory.
  ///
  /// In en, this message translates to:
  /// **'Create New Directory'**
  String get create_new_directory;

  /// No description provided for @directory_name.
  ///
  /// In en, this message translates to:
  /// **'Directory Name'**
  String get directory_name;

  /// No description provided for @new_document.
  ///
  /// In en, this message translates to:
  /// **'New Document'**
  String get new_document;

  /// No description provided for @create_new_document.
  ///
  /// In en, this message translates to:
  /// **'Create New Document'**
  String get create_new_document;

  /// No description provided for @document_name.
  ///
  /// In en, this message translates to:
  /// **'Document Name'**
  String get document_name;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @name_cannot_be_empty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty.'**
  String get name_cannot_be_empty;

  /// No description provided for @already_exists.
  ///
  /// In en, this message translates to:
  /// **'already exists.'**
  String get already_exists;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @import_image.
  ///
  /// In en, this message translates to:
  /// **'Import Image'**
  String get import_image;

  /// No description provided for @adjust_eraser_width.
  ///
  /// In en, this message translates to:
  /// **'Adjust Eraser Width:'**
  String get adjust_eraser_width;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current: '**
  String get current;

  /// No description provided for @erase_with_finger.
  ///
  /// In en, this message translates to:
  /// **'Erase with Finger'**
  String get erase_with_finger;

  /// No description provided for @selection_shape.
  ///
  /// In en, this message translates to:
  /// **'Selection Shape'**
  String get selection_shape;

  /// No description provided for @lasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso'**
  String get lasso;

  /// No description provided for @rectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get rectangle;

  /// No description provided for @selection_rule.
  ///
  /// In en, this message translates to:
  /// **'Selection Rule'**
  String get selection_rule;

  /// No description provided for @select_on_touch.
  ///
  /// In en, this message translates to:
  /// **'Select on touch'**
  String get select_on_touch;

  /// No description provided for @will_select_touching.
  ///
  /// In en, this message translates to:
  /// **'When activated selects everything that touches the selected area.'**
  String get will_select_touching;

  /// No description provided for @select_with_finger.
  ///
  /// In en, this message translates to:
  /// **'Select with Finger'**
  String get select_with_finger;

  /// No description provided for @pen_type.
  ///
  /// In en, this message translates to:
  /// **'Pen Type'**
  String get pen_type;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @fountain_pen.
  ///
  /// In en, this message translates to:
  /// **'Fountain Pen'**
  String get fountain_pen;

  /// No description provided for @pencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get pencil;

  /// No description provided for @marker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get marker;

  /// No description provided for @draw_straight_lines.
  ///
  /// In en, this message translates to:
  /// **'Draw Straight Lines'**
  String get draw_straight_lines;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @auto_detect.
  ///
  /// In en, this message translates to:
  /// **'Auto-Detect'**
  String get auto_detect;

  /// No description provided for @hold_for_line.
  ///
  /// In en, this message translates to:
  /// **'Hold for Line'**
  String get hold_for_line;

  /// No description provided for @align_xy.
  ///
  /// In en, this message translates to:
  /// **'Align XY'**
  String get align_xy;

  /// No description provided for @lines_will_tend_to.
  ///
  /// In en, this message translates to:
  /// **'Lines will tend to run parallel to XY'**
  String get lines_will_tend_to;

  /// No description provided for @input.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get input;

  /// No description provided for @draw_with_finger.
  ///
  /// In en, this message translates to:
  /// **'Draw with Finger'**
  String get draw_with_finger;

  /// No description provided for @shape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get shape;

  /// No description provided for @line.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get line;

  /// No description provided for @arrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get arrow;

  /// No description provided for @rect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get rect;

  /// No description provided for @circle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get circle;

  /// No description provided for @triangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get triangle;

  /// No description provided for @pentagon.
  ///
  /// In en, this message translates to:
  /// **'Pentagon'**
  String get pentagon;

  /// No description provided for @hexagon.
  ///
  /// In en, this message translates to:
  /// **'Hexagon'**
  String get hexagon;

  /// No description provided for @octagon.
  ///
  /// In en, this message translates to:
  /// **'Octagon'**
  String get octagon;

  /// No description provided for @shape_origin.
  ///
  /// In en, this message translates to:
  /// **'Shape Origin'**
  String get shape_origin;

  /// No description provided for @corner.
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get corner;

  /// No description provided for @center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get center;

  /// No description provided for @snap_to_grid.
  ///
  /// In en, this message translates to:
  /// **'Snap to Grid'**
  String get snap_to_grid;

  /// No description provided for @laser_width.
  ///
  /// In en, this message translates to:
  /// **'Laser Width'**
  String get laser_width;

  /// No description provided for @leave_trail.
  ///
  /// In en, this message translates to:
  /// **'Leave Trail'**
  String get leave_trail;

  /// No description provided for @fade_out_duration.
  ///
  /// In en, this message translates to:
  /// **'Fade Out Duration'**
  String get fade_out_duration;

  /// No description provided for @fade_out.
  ///
  /// In en, this message translates to:
  /// **'Fade Out'**
  String get fade_out;

  /// No description provided for @adjust_stroke_width.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stroke Width'**
  String get adjust_stroke_width;

  /// No description provided for @select_color.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get select_color;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @page_setup.
  ///
  /// In en, this message translates to:
  /// **'Page Setup'**
  String get page_setup;

  /// No description provided for @page_size.
  ///
  /// In en, this message translates to:
  /// **'Page Size'**
  String get page_size;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @background_color.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get background_color;

  /// No description provided for @set_new_color.
  ///
  /// In en, this message translates to:
  /// **'Set New Color'**
  String get set_new_color;

  /// No description provided for @apply_to_all_pages.
  ///
  /// In en, this message translates to:
  /// **'Apply to all Pages'**
  String get apply_to_all_pages;

  /// No description provided for @old.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get old;

  /// No description provided for @new_.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get new_;

  /// No description provided for @palette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get palette;

  /// No description provided for @rgba.
  ///
  /// In en, this message translates to:
  /// **'RGBA'**
  String get rgba;

  /// No description provided for @wheel.
  ///
  /// In en, this message translates to:
  /// **'Wheel'**
  String get wheel;

  /// No description provided for @hex_code.
  ///
  /// In en, this message translates to:
  /// **'Hex Code'**
  String get hex_code;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @new_name.
  ///
  /// In en, this message translates to:
  /// **'New Name'**
  String get new_name;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @elements.
  ///
  /// In en, this message translates to:
  /// **'Elements'**
  String get elements;

  /// No description provided for @coming_soon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get coming_soon;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
