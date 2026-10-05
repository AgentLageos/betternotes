import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/features/editor/components/top_bar/editor_top_bar_panel.dart';
import 'package:betternotes/features/settings/components/tools_settings.dart';
import '../../../core/providers/global_providers.dart';
import '../../../l10n/app_localizations.dart';

final editorIndex = 0;

class EditorSettings extends ConsumerWidget {
  const EditorSettings({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final language = AppLocalizations.of(context)!;


    final setup = ref.watch(editorSetupProvider)[0];

    final editorIndex = 0;

    return ListView(

      padding: const EdgeInsets.all(16),

      children: [
        Text(language.editor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),

        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2,), borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: EditorTopBarPanel(),
          ),
        ),

        const SizedBox(height: 12),
        ResizableToolbar(),
        const SizedBox(height: 10),

        ListTile(
          title: Text(language.customize_tools),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => ToolSelectorPage(),),);},
        ),

        const SizedBox(height: 12),
        _NumberSettingRow(label: language.number_of_widths, initialValue: setup.widths.length, onChanged: (val) => ref.read(editorSetupProvider.notifier).setAmountOfWidths(editorIndex, val)),
        const SizedBox(height: 12),
        _NumberSettingRow(label: language.number_of_colors, initialValue: setup.colors.length, onChanged: (val) => ref.read(editorSetupProvider.notifier).setAmountOfColors(editorIndex, val)),
        const SizedBox(height: 12),

      ],
    );
  }
}

class _NumberSettingRow extends StatelessWidget {
  final String label;
  final int initialValue;
  final Function(int) onChanged;

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
              final number = int.tryParse(text);
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

              // Divider Overlay
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

                          //check min width
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
                            splits[i] = left / w;//live adjust panels
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