import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/global_providers.dart';
import '../../editor/models/tools/eraser_tool.dart';
import '../../editor/models/tools/line_tool.dart';
import '../../editor/models/tools/selection_tool.dart';
import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/shape_tool.dart';



import '../../../l10n/app_localizations.dart';


enum ToolType {
  penTool,
  eraserTool,
  selectionTool,
  shapeTool,
  lineTool,
  laserTool
  ;

  IconData get icon {
    switch (this) {
      case ToolType.penTool:
        return Icons.edit;
      case ToolType.eraserTool:
        return Icons.edit_off;
      case ToolType.selectionTool:
        return Icons.crop_free;
      case ToolType.shapeTool:
        return Icons.crop_3_2;
      case ToolType.lineTool:
        return Icons.horizontal_rule;
      case ToolType.laserTool:
        return Icons.light_mode_outlined;

    }
  }
}

final editorIndex=0;

class ToolSelectorPage extends ConsumerStatefulWidget {
  const ToolSelectorPage({super.key});

  @override
  ConsumerState<ToolSelectorPage> createState() => _ToolSelectorPageState();
}

class _ToolSelectorPageState extends ConsumerState<ToolSelectorPage> {
  final List<ToolType> availableTools = [
    ToolType.penTool,
    ToolType.eraserTool,
    ToolType.selectionTool,
    ToolType.shapeTool,
    ToolType.lineTool,
    ToolType.laserTool,
  ];

  //final List<Icon> tools = [];
  late final setup = ref.read(editorSetupProvider)[editorIndex];

  //late final List<Icon> tools = ref.read(editorSetupProvider)[editorIndex].spaces;

  late List<ToolType> tools = setup.tools.map((tool) {
    switch (tool.type) {
      case 'PenTool':
        return ToolType.penTool;
      case 'EraserTool':
        return ToolType.eraserTool;
      case 'SelectionTool':
        return ToolType.selectionTool;
      case 'ShapeTool':
        return ToolType.shapeTool;
      case 'LineTool':
        return ToolType.lineTool;
      case 'LaserTool':
        return ToolType.laserTool;
      default:
        return ToolType.penTool;
    }
  }).toList();

  void addTool(ToolType tool) {
    setState(() {
      tools.add(tool);
    });
  }

  void removeTool(int index) {
    setState(() {
      tools.removeAt(index);
    });
  }

  void finishSelection() {

    List<Tool> newTools = tools.map((tool) {
      switch (tool) {
        case ToolType.penTool:
          return PenTool();
        case ToolType.eraserTool:
          return EraserTool();
        case ToolType.selectionTool:
          return SelectionTool();
        case ToolType.shapeTool:
          return ShapeTool();
        case ToolType.lineTool:
          return LineTool();
        case ToolType.laserTool:
          return LaserTool();
        default:
          return PenTool();
      }
    }).toList();
    ref.read(editorSetupProvider.notifier).setTools(editorIndex, newTools);
    Navigator.pop(context, tools);

  }

  @override
  Widget build(BuildContext context) {


    final language = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(language.customize_tools),
        actions: [

          //IconButton(icon: const Icon(Icons.check), onPressed: finishSelection,)
          ElevatedButton(
            onPressed: (finishSelection),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              alignment: Alignment.center,

            ),
            child: Text(language.apply, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ),

          const SizedBox(width: 20)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 Auswahlbereich

            const SizedBox(height: 20),

            // 🔹 Toolbar
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];

                  return GestureDetector(
                    onTap: () => removeTool(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(tool.icon),
                    ),
                  );
                },
              )
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: availableTools.map((tool) {
                return GestureDetector(
                  onTap: () => addTool(tool),
                  child: Icon(tool.icon),
                );
              }).toList(),
            )

          ],
        ),
      ),
    );
  }
}