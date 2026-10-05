import 'package:betternotes/core/providers/global_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';

class DeveloperSettings extends ConsumerStatefulWidget {
  const DeveloperSettings({super.key});

  @override
  ConsumerState<DeveloperSettings> createState() => _DeveloperSettingsState();
}

class _DeveloperSettingsState extends ConsumerState<DeveloperSettings> {
  final TextEditingController _pathController = TextEditingController();



  //open android app settings
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  //check permission, open app settings
  Future<void> _handleStoragePermission() async {
    var status = await Permission.storage.status;

    if (status.isDenied) {
      status = await Permission.storage.request();
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speicherzugriff erlaubt")),
      );
    }
  }


  void _applyPath() {
    final path = _pathController.text;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Pfad angewendet: $path")),
    );

    debugPrint("Pfad: $path");
  }

  void _extraAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Extra Button gedrückt")),
    );
  }

  @override
  Widget build(BuildContext context) {

    final path = ref.watch(platformProvider).homeDirectory;
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
            //RestartWidget.restartApp(context);

          },
        ),



        const SizedBox(height: 20),

        if (Platform.isAndroid)
        ListTile(
          title: Text(language.manage_app_permissions),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _openAppSettings,
        ),


        /*
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _handleStoragePermission,
                child: const Text("Speicherzugriff prüfen"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _openAppSettings,
                child: const Text("App-Einstellungen öffnen"),
              ),
            ],
          ),

         */
        /*

        const SizedBox(height: 20),

        /// 🔹 Pfad Eingabe
        TextField(
          controller: _pathController,
          decoration: const InputDecoration(
            labelText: "Pfad eingeben",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _NumberSettingRow(label: "Path", initialValue: path, onChanged: (val) {
          //ref.read(platformProvider.notifier).changeHomeDir(val);
          //setPath(val);

        }),

        const SizedBox(height: 10),

        /// 🔹 Anwenden Button
        ElevatedButton(
          onPressed: _applyPath,
          child: const Text("Pfad anwenden"),
        ),

        const SizedBox(height: 30),

        /// 🔹 Extra Button
        ElevatedButton(
          onPressed: _extraAction,
          child: const Text("Extra Button"),
        ),

         */
      ],
    );
  }


  Future<void> setPath(String path) async {

    final hasAccess = await _canAccess(path);

    if (!hasAccess) {

      await openAppSettings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitte Speicherzugriff in den Einstellungen erlauben"),
        ),
      );
      return;
    }


    //final prefs = await SharedPreferences.getInstance();
    //await prefs.setString('path', path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pfad erfolgreich gesetzt")),
    );
  }

  Future<bool> _canAccess(String path) async {
    try {
      final dir = Directory(path);

      if (!await dir.exists()) return false;

      dir.listSync();
      return true;
    } catch (e) {
      return false;
    }
  }



}


class _NumberSettingRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;

  const _NumberSettingRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialValue.toString());

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(label),
        ),
        Expanded(
          flex: 2, // 50% / 50%
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            onSubmitted: (text) {
              final val = text;
              if (val != null) {
                onChanged(val);
              }
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: initialValue.toString(),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}