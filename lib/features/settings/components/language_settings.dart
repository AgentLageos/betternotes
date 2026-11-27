import 'package:flutter/material.dart';
import 'package:betternotes/l10n/app_localizations.dart';

class LanguageSettings extends StatefulWidget {
  const LanguageSettings({super.key});

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {

  String selectedLanguage = "de";

  final languages = {
    "de": "Deutsch",
    "en": "English",
    "fr": "Français",
    "es": "Español",
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        Text(
          AppLocalizations.of(context)!.language,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        ...languages.entries.map((entry) {
          return RadioListTile<String>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: selectedLanguage,
            onChanged: (value) {
              setState(() {
                selectedLanguage = value!;
              });
            },
          );
        }),
      ],
    );
  }
}