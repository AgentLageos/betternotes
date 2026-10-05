import 'package:betternotes/features/settings/components/about_settings.dart';
import 'package:betternotes/features/settings/components/design_settings.dart';
import 'package:betternotes/features/settings/components/developer_settings.dart';
import 'package:betternotes/features/settings/components/document_settings.dart';
import 'package:betternotes/features/settings/components/editor_settings.dart';
import 'package:betternotes/features/settings/components/general_settings.dart';
import 'package:betternotes/features/settings/components/language_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';


final List<Widget> settingsContents = [
  GeneralSettings(),
  DesignSettings(),
  EditorSettings(),
  DocumentSettings(),
  const DeveloperSettings(),
  const AboutSettings(),
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int selectedIndex = 0;
  void initState() {
    super.initState();
    loadLastSettingsCategory();
  }
  Future<void> loadLastSettingsCategory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedIndex = prefs.getInt('lastSettingsCategory') ?? 0;

    });
  }

  @override
  Widget build(BuildContext context) {
    final wideScreen = MediaQuery.of(context).size.width >= 700;

    final language = AppLocalizations.of(context)!;

    final settingsCategories = [
      language.general,
      language.design,
      language.editor,
      language.document,
      language.danger_zone,
      language.about
    ];

    return Scaffold(
      appBar: AppBar(title: Text(language.settings)),
      body: wideScreen ? _desktopLayout(settingsCategories) : _mobileLayout(settingsCategories),
    );
  }

  // for big screen
  Widget _desktopLayout(List<String> settingsCategories) {
    return Row(
      children: [

        // Linke Kategorien
        SizedBox(
          width: 250,
          child: ListView.builder(
            itemCount: settingsCategories.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(settingsCategories[index]),
                selected: selectedIndex == index,
                onTap: () async {
                  setState(() {selectedIndex = index;});
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('lastSettingsCategory', index);
                },
              );
            },
          ),
        ),

        const VerticalDivider(width: 1),


        Expanded(
          child: settingsContents[selectedIndex],
        ),
      ],
    );
  }

  //small  screen
  Widget _mobileLayout(List<String> settingsCategories) {
    return ListView.builder(
      itemCount: settingsCategories.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(settingsCategories[index]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(settingsCategories[index])),
                  body: settingsContents[index],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
