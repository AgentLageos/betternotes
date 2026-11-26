import 'package:betternotes/core/providers/global_providers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';

class DeveloperSettings extends ConsumerStatefulWidget {
  const DeveloperSettings({super.key});

  @override
  ConsumerState<DeveloperSettings> createState() => _DeveloperSettingsState();
}

class _DeveloperSettingsState extends ConsumerState<DeveloperSettings> {
  //open android app settings
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }


  @override
  Widget build(BuildContext context) {

    final settings = ref.watch(settingsProvider);

    final language = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          language.danger_zone,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        SwitchListTile(
          title: Text(language.debug_mode),
          value: settings.debugMode,
          onChanged: (value) async {
            await ref.read(settingsProvider.notifier).setDebugMode(value);

          },
        ),

        SwitchListTile(
          title: Text(language.mesh_renderer),
          subtitle: Text(language.mesh_renderer_hint),
          value: settings.meshRenderer,
          onChanged: (value) async {
            await ref.read(settingsProvider.notifier).setMeshRenderer(value);
          },
        ),



        const SizedBox(height: 20),

        if (Platform.isAndroid)
        ListTile(
          title: Text(language.manage_app_permissions),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _openAppSettings,
        ),


      ],
    );
  }
}
