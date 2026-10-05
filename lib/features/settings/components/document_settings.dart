import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/core/utils/build_color_tile.dart';
import '../../../core/providers/global_providers.dart';
import '../models/settings.dart';
import '../providers/settings_notifier.dart';
import '../../../l10n/app_localizations.dart';

final editorIndex = 0;









final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(() => SettingsNotifier());

class DocumentSettings extends ConsumerStatefulWidget {
  const DocumentSettings({super.key});

  @override
  ConsumerState<DocumentSettings> createState() => _DocumentSettingsState();
}

class _DocumentSettingsState extends ConsumerState<DocumentSettings> {


    bool showAdvanced = false;

    @override
    Widget build(BuildContext context) {

      final language = AppLocalizations.of(context)!;

    final setup = ref.watch(editorSetupProvider)[0];

    final editorIndex = 0;

    return ListView(

      padding: const EdgeInsets.all(16),

      children: [
        Text(language.default_page_setup, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),

        const SizedBox(height: 20),

        _NumberSettingRow(label: language.page_height, initialValue: setup.defaultPage.pageHeight, onChanged: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight:  val)),
        const SizedBox(height: 10),
        _NumberSettingRow(label: language.page_width, initialValue: setup.defaultPage.pageWidth, onChanged: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageWidth: val)),
        const SizedBox(height: 10),
        ExpansionTile(
            title: Text(language.page_size_presets),
            initiallyExpanded: showAdvanced,
            onExpansionChanged: (expanded) {
              setState(() {
                showAdvanced = expanded;
              });
            },
            children: [
              ListTile(
                title: Text("A3 "+language.portrait, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 420, pageWidth: 297);},
              ),
              ListTile(
                title: Text("A3 "+language.landscape, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 297, pageWidth: 410);},
              ),
              ListTile(
                title: Text("A4 "+language.portrait, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {
                  ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 297, pageWidth: 210);
                },
              ),
              ListTile(
                title: Text("A4 "+language.landscape, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {
                  ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 210, pageWidth: 297);
                },
              ),
              ListTile(
                title: Text("A5 "+language.portrait, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {
                  ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 210, pageWidth: 148);
                },
              ),
              ListTile(
                title: Text("A5 "+language.landscape, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                onTap: () async {
                  ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageHeight: 148, pageWidth: 210);
                },
              ),

            ]),
        buildColorTile(context: context, label: language.page_color, color: setup.defaultPage.pageColor, onColorPicked: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, pageColor: val)),


        const SizedBox(height: 10),



        _NumberSettingRow(label: language.vertical_space, initialValue: setup.defaultPage.verticalSpaces.isNotEmpty ? setup.defaultPage.verticalSpaces.first : 0, onChanged: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, verticalSpace:  val)),
        const SizedBox(height: 10),
        _NumberSettingRow(label: language.horizontal_space, initialValue: setup.defaultPage.horizontalSpaces.isNotEmpty ? setup.defaultPage.horizontalSpaces.first : 0, onChanged: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, horizontalSpace: val)),
        const SizedBox(height: 10),
        _NumberSettingRow(label: language.background_lines_width, initialValue: setup.defaultPage.backgroundStrokes.isNotEmpty ? setup.defaultPage.backgroundStrokes.first.points.first.width : 0.4, onChanged: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, backgroundStrokeWidth: val)),
        const SizedBox(height: 10),
        buildColorTile(context: context, label: language.background_lines_color, color: setup.defaultPage.backgroundStrokes.isNotEmpty ? setup.defaultPage.backgroundStrokes.first.color : Colors.grey, onColorPicked: (val) => ref.read(editorSetupProvider.notifier).setDefaultPage(editorIndex: editorIndex, backgroundStrokeColor: val)),
        const SizedBox(height: 12),

      ],
    );
  }

}

class _NumberSettingRow extends StatelessWidget {
  final String label;
  final double initialValue;
  final Function(double) onChanged;

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
          child: Text(label),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            //textAlign: TextAlign.right,
            onSubmitted: (text) {
              final number = double.tryParse(text);
              if (number != null) {
                onChanged(number);
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




// Zielseite
class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("advanced settings"),
      ),
      body: const Center(
        child: Text("Hier kommen weitere Einstellungen hin"),
      ),
    );
  }
}



double measureTextWidth(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();

  return tp.width;
}

class ResizableToolbar extends ConsumerStatefulWidget {
  const ResizableToolbar({super.key});

  @override
  ConsumerState<ResizableToolbar> createState() => _ResizableToolbarState();
}

class _ResizableToolbarState extends ConsumerState<ResizableToolbar> {
  late List<double> spaces = ref.read(editorSetupProvider)[editorIndex].spaces;

  late List<double> splits = [spaces[0], spaces[1]+spaces[0], spaces[2]+spaces[1]+spaces[0]];

  @override
  Widget build(BuildContext context) {

    final language = AppLocalizations.of(context)!;


    List<String> titles = [language.tools, language.widths, language.colors, language.undo_redo];
    const textStyle = TextStyle(fontWeight: FontWeight.bold);
    //final minWidths = titles.map((t) => measureTextWidth(t, textStyle) + 32).toList();
    final minWidths = [50, 50, 50, 50];

    //print(minWidths);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return SizedBox(
          height: 48,
          width: w,
          child: Stack(
            children: [
              // Panels
              Row(
                children: List.generate(4, (i) {
                  final widths = [splits[0], splits[1] - splits[0], splits[2] - splits[1], 1 - splits[2],];
                  return SizedBox(
                    width: widths[i] * w,
                    child: Container(
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      child: Text(
                        titles[i],
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: textStyle,
                      ),
                    ),
                  );
                }),
              ),
              ...List.generate(3, (i) {
                double left = splits[i] * w;

                return StatefulBuilder(
                  builder: (context, setDividerState) {
                    return Positioned(
                      left: left - 5,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          double newLeft = left + details.delta.dx;

                          final leftEdge =
                          i == 0 ? 0.0 : splits[i - 1] * w;
                          final rightEdge =
                          i == splits.length - 1 ? w : splits[i + 1] * w;

                          if (newLeft - leftEdge < minWidths[i]) {
                            newLeft = leftEdge + minWidths[i];
                          }
                          if (rightEdge - newLeft < minWidths[i + 1]) {
                            newLeft = rightEdge - minWidths[i + 1];
                          }

                          setDividerState(() {
                            left = newLeft;
                          });

                          setState(() {
                            splits[i] = left / w; // Panels live anpassen
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          print(splits);
                          ref.read(editorSetupProvider.notifier).setSpaces(editorIndex, [splits[0], splits[1]-splits[0], splits[2]-splits[1], 1-splits[2]]);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: Container(
                            width: 20,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}