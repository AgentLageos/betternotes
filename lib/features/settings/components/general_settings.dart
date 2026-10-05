import 'package:betternotes/core/providers/global_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

class GeneralSettings extends ConsumerWidget {
  GeneralSettings({super.key});

  String selectedLanguage = 'en';

  final languages = [
    'en',
    'de',
  ];





  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final language = AppLocalizations.of(context)!;

    selectedLanguage = ref.read(settingsProvider).language.toString();


    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        Text(
          language.general,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        ListTile(
          title: Text(language.language),
          subtitle: Text(selectedLanguage),

          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down),
            onSelected: (value) {

              ref.read(settingsProvider.notifier).setLanguage(value);

                selectedLanguage = value;

            },
            itemBuilder: (context) {
              return languages.map((language) {
                return PopupMenuItem(
                  value: language,
                  child: Text(language),
                );
              }).toList();
            },
          ),
        ),




      ],
    );
  }
}