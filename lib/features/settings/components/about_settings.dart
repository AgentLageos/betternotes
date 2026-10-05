import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/app_localizations.dart';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  String version = "";
  String buildNumber = "";

  late final language = AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState((){
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(language.about, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        ListTile(title: Text(language.app_version), subtitle: Text(version)),
        ListTile(title: Text(language.build_number), subtitle: Text(buildNumber)),
        ListTile(title: Text(language.developed_by), subtitle: Text("Lageos")),
        const Divider(),
        ListTile(
          title: Text(language.open_source_licenses),
          subtitle: Text(language.view_licenses_of_used_libraries),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: "BetterNotes",
              applicationVersion: version,
              applicationLegalese: "© 2026 Lageos",
            );
          },
        ),
      ],
    );
  }
}