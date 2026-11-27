import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/features/editor/models/page/editor_setup.dart';
import 'package:betternotes/features/editor/providers/editor_setup_notifier.dart';
import 'package:betternotes/features/settings/providers/settings_notifier.dart';
import '../../features/editor/models/page/platform.dart';
import '../../features/settings/models/settings.dart';
import 'platform_notifier.dart';

// Per-document state (D2): documentProvider(docID), openDocumentsProvider, activeDocumentProvider.
export 'package:betternotes/features/editor/providers/document_notifier.dart' show documentProvider, DocumentNotifier;
export 'package:betternotes/features/editor/providers/open_documents_notifier.dart' show openDocumentsProvider, activeDocumentProvider;




final editorSetupProvider = NotifierProvider<EditorSetupNotifier, List<EditorSetup>>(EditorSetupNotifier.new);

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final platformProvider = NotifierProvider<PlatformSettingsNotifier, PlatformSettings>(() => PlatformSettingsNotifier('', ''));


