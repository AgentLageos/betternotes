import 'package:betternotes/core/navigation/navigator_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/editor_setup.dart';
import 'package:betternotes/features/editor/providers/documents_notifier.dart';
import 'package:betternotes/features/editor/providers/editor_setup_notifier.dart';
import 'package:betternotes/features/settings/providers/settings_notifier.dart';
import '../../features/editor/models/page/platform.dart';
import '../../features/settings/models/settings.dart';
import 'platform_notifier.dart';




final documentsProvider = NotifierProvider<DocumentsNotifier, List<DocumentModel>>(DocumentsNotifier.new);

final editorSetupProvider = NotifierProvider<EditorSetupNotifier, List<EditorSetup>>(EditorSetupNotifier.new);

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final platformProvider = NotifierProvider<PlatformSettingsNotifier, PlatformSettings>(() => PlatformSettingsNotifier('', ''));



//final navigatonStateProvider = NotifierProvider<NavigatonStateNotifier, NavigationState>(() => NavigatonStateNotifier());
//final platformProvider = NotifierProvider<PlatformSettingsNotifier, PlatformSettings>(PlatformSettingsNotifier.new);


//final navigatorProvider = NotifierProvider<NavigatorNotifier, NavigatorModel>(NavigatorNotifier.new);


//final currentPagesProvider = NotifierProvider<CurrentPagesNotifier, List<int>>(CurrentPagesNotifier.new);

