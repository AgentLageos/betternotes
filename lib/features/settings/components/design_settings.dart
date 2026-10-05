import 'package:betternotes/core/components/color_picker.dart';
import 'package:betternotes/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings.dart';
import '../providers/settings_notifier.dart';

import '../../../l10n/app_localizations.dart';


final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(() => SettingsNotifier());

class DesignSettings extends ConsumerStatefulWidget {
  const DesignSettings({super.key});

  @override
  ConsumerState<DesignSettings> createState() => _DesignSettingsState();
}

class _DesignSettingsState extends ConsumerState<DesignSettings> {
  bool showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final language = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(language.design, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
        const SizedBox(height: 20),
        SwitchListTile(
          title: Text(language.dark_mode),
          value: settings.darkMode,
          onChanged: (value) async {
            await ref.read(settingsProvider.notifier).setDarkMode(value);
            RestartWidget.restartApp(context);

            },
        ),

        SizedBox(height: 16),

        // 2️⃣ Akzentfarbe

        buildColorTile(
          context: context,
          label: language.accent_color,
          color: settings.primary,
          onColorPicked: (color) async {
            await ref.read(settingsProvider.notifier).setAccentColor(color);
            RestartWidget.restartApp(context);
            },
        ),

        const SizedBox(height: 16),

        ExpansionTile(
        title: Text(language.color_themes),
        initiallyExpanded: showAdvanced,
        onExpansionChanged: (expanded) {
        setState(() {
        showAdvanced = expanded;
        });
        },
        children: [
          ListTile(
            title: Text(language.relaxing_blue, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            onTap: () async {
              await ref.read(settingsProvider.notifier).setColors(primary: Colors.blue, onPrimary: Colors.white, secondary: Colors.blue, onSecondary: Colors.white, surface: Colors.white, onSurface: Colors.black, error: Colors.red, onError: Colors.pinkAccent);
              RestartWidget.restartApp(context);
            },
          ),
          ListTile(
            title: Text(language.retrowave, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            onTap: () async {
              await ref.read(settingsProvider.notifier).setColors(primary: Color(0xFFCD5672), onPrimary: Color(0xFF2D4DEF), secondary: Color(0xFFDE7C4B), onSecondary: Color(0xFFFFFF99), surface: Color(0xFF700052), onSurface: Colors.tealAccent, error: Colors.red, onError: Colors.pinkAccent);
              RestartWidget.restartApp(context);
            },
          ),
          ListTile(
            title: Text(language.enter_matrix, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            onTap: () async {
              await ref.read(settingsProvider.notifier).setColors(primary: Colors.grey.shade800, onPrimary: Colors.green, secondary: Colors.grey.shade800, onSecondary: Colors.greenAccent, surface: Colors.black54, onSurface: Colors.lightGreen, error: Colors.red, onError: Colors.pinkAccent);
              RestartWidget.restartApp(context);
            },
          )
        ]),

        const SizedBox(height: 16),

        ExpansionTile(
          title: Text(language.advanced_color_settings),
          initiallyExpanded: showAdvanced,
          onExpansionChanged: (expanded) {
            setState(() {
              showAdvanced = expanded;
            });
          },
          children: [
            buildColorTile(
              context: context,
              label: language.primary_color,
              color: settings.primary,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setPrimaryColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.on_primary_color,
              color: settings.onPrimary,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setOnPrimaryColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.secondary_color,
              color: settings.secondary,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setSecondaryColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.on_secondary_color,
              color: settings.onSecondary,
              onColorPicked: (color) async {
                ref.read(settingsProvider.notifier).setOnSecondaryColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.surface_color,
              color: settings.surface,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setSurfaceColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.on_surface_color,
              color: settings.onSurface,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setOnSurfaceColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.error_color,
              color: settings.error,
              onColorPicked: (color) async {
                ref.read(settingsProvider.notifier).setErrorColor(color);
                RestartWidget.restartApp(context);
              },
            ),
            buildColorTile(
              context: context,
              label: language.on_error_color,
              color: settings.error,
              onColorPicked: (color) async {
                await ref.read(settingsProvider.notifier).setOnErrorColor(color);
                RestartWidget.restartApp(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget buildColorTile({
    required BuildContext context,
    required String label,
    required Color color,
    required ValueChanged<Color> onColorPicked,
  }) {
    return ListTile(
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
      trailing: CircleAvatar(
        backgroundColor: color,
        radius: 16,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade500, width: 2),
          ),
        ),
      ),
      onTap: () async {
        final picked = await pickColor(context, color);
        if (picked != null) onColorPicked(picked);
      },
    );
  }

  Future<Color?> pickRGBColor(BuildContext context, Color current) async {
    int r = current.red;
    int g = current.green;
    int b = current.blue;
    int a = current.alpha;

    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Farbe auswählen"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              Color preview = Color.fromARGB(a, r, g, b);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: preview,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade500, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // R Slider
                  buildSlider("R", r, Colors.red, (val) => setStateDialog(() => r = val.toInt())),
                  // G Slider
                  buildSlider("G", g, Colors.green, (val) => setStateDialog(() => g = val.toInt())),
                  // B Slider
                  buildSlider("B", b, Colors.blue, (val) => setStateDialog(() => b = val.toInt())),
                  // Alpha Slider
                  buildSlider("A", a, Colors.grey, (val) => setStateDialog(() => a = val.toInt())),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Abbrechen")),
            TextButton(onPressed: () => Navigator.of(context).pop(Color.fromARGB(a, r, g, b)), child: const Text("OK")),
          ],
        );
      },
    );
  }

  Widget buildSlider(String label, int value, Color activeColor, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value.toDouble(),
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 35, child: Text(value.toString())),
      ],
    );
  }
}

Future<Color?> pickRGBColor(BuildContext context, Color current, String message) async {
  int r = current.red;
  int g = current.green;
  int b = current.blue;
  int a = current.alpha;

  return showDialog<Color>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Farbe auswählen"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            Color preview = Color.fromARGB(a, r, g, b);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Vorschau
                CircleAvatar(
                  backgroundColor: preview,
                  radius: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade500, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // R Slider
                Row(
                  children: [
                    const Text("R"),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 255,
                        value: r.toDouble(),
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setDialogState(() => r = val.toInt());
                        },
                      ),
                    ),
                    Text(r.toString()),
                  ],
                ),
                // G Slider
                Row(
                  children: [
                    const Text("G"),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 255,
                        value: g.toDouble(),
                        activeColor: Colors.green,
                        onChanged: (val) {
                          setDialogState(() => g = val.toInt());
                        },
                      ),
                    ),
                    Text(g.toString()),
                  ],
                ),
                // B Slider
                Row(
                  children: [
                    const Text("B"),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 255,
                        value: b.toDouble(),
                        activeColor: Colors.blue,
                        onChanged: (val) {
                          setDialogState(() => b = val.toInt());
                        },
                      ),
                    ),
                    Text(b.toString()),
                  ],
                ),
                // Optional: Alpha Slider
                Row(
                  children: [
                    const Text("A"),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 255,
                        value: a.toDouble(),
                        onChanged: (val) {
                          setDialogState(() => a = val.toInt());
                        },
                      ),
                    ),
                    Text(a.toString()),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(Color.fromARGB(a, r, g, b)),
            child: const Text("OK"),
          ),
        ],
      );
    },
  );
}


