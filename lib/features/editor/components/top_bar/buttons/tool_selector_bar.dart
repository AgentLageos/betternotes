import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'package:betternotes/features/editor/components/top_bar/buttons/tool_button.dart';
import 'package:betternotes/features/editor/models/tools/eraser_tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/selection_tool.dart';
import '../../../models/tools/line_tool.dart';
import 'package:betternotes/features/editor/models/tools/shape_tool.dart';
import 'package:betternotes/features/editor/models/tools/tool.dart';
import '../../../../../l10n/app_localizations.dart';
import 'package:betternotes/core/providers/global_providers.dart';



enum ToolType {
  penTool,
  eraserTool,
  selectionTool,
  shapeTool,
  lineTool,
  laserTool,
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




class ToolSelectorBar extends ConsumerStatefulWidget {
  final double height;
  final Color backgroundColor;

  const ToolSelectorBar({
    super.key,
    required this.height,
    required this.backgroundColor,
  });

  @override
  ConsumerState<ToolSelectorBar> createState() => _ToolSelectorBarState();
}

class _ToolSelectorBarState extends ConsumerState<ToolSelectorBar> {

  final editorIndex = 0;

  int selectedIndex = 0;
  double eraserWidth = 10;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        //selectedIndex = context.read<GlobalState>().selectedTool;       //overwrite colors and currently selected with global_state
        selectedIndex =ref.read(editorSetupProvider.select((editors) => editors[editorIndex].toolIndex));
      });
    });
  }






  @override
  Widget build(BuildContext context) {


    final editorSetup = ref.watch(editorSetupProvider.notifier).state[editorIndex];
    //final tools = editorSetup.toolsOld;
    final tools = editorSetup.tools;


    return Container(
      height: widget.height,
      //color: widget.backgroundColor,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final toolType = tools[index];
          final isSelected = index == selectedIndex;

          final GlobalKey buttonKey = GlobalKey();

          return GestureDetector(
            key: buttonKey,
            onTap: () {
              setState(() {
                selectedIndex = index;
                ref.read(editorSetupProvider.notifier).setToolIndex(editorIndex, index);
                //Provider.of<GlobalState>(context, listen: false).setSelectedTool(toolType);
              });
            },
            onLongPress: () => _editTool(toolType, index, buttonKey),
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.onSurface: Colors.transparent,
                  width: 3,
                ),
              ),
              //child: buildToolbox(toolType, index),
              child: ToolButton(toolIndex: index),
            ),
          );
        },
      ),
    );
  }


  void _editTool(Tool toolType, int toolIndex, buttonKey) {
    print(toolType);
    switch (toolType) {
      case PenTool():
        _showPenSetupDialog(toolIndex, buttonKey);
      case EraserTool():
        _showEraserWidthDialog(toolIndex, buttonKey);
      case SelectionTool():
        _showSelectionSetupDialog(toolIndex, buttonKey);
      case ShapeTool():
        _showShapeSetupDialog(toolIndex, buttonKey);
      case LineTool():
        _showLineSetupDialog(toolIndex, buttonKey);
      case LaserTool():
        _showLaserSetupDialog(toolIndex, buttonKey);
    }


  }








  void _showEraserWidthDialog(int toolIndex, GlobalKey buttonKey) {

    final language = AppLocalizations.of(context)!;
    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    if (tool is EraserTool) {
      final currentWidth = tool.width;

      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      double tempWidth = currentWidth;
      bool finger = tool.finger;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(language.adjust_eraser_width),
                    Slider(
                      min: 1,
                      max: 50,
                      divisions: 49,
                      value: tempWidth,
                      label: "${tempWidth.round()}",
                      onChanged: (value) {
                        setState(() {
                          tempWidth = value;
                        });
                      },
                    ),
                    SizedBox(height: 4),
                    Text("${language.current} ${tempWidth.toStringAsFixed(1)}"),

                    const Divider(),

                    Text(
                      language.input,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    SwitchListTile(
                      dense: true,
                      title: Text(language.erase_with_finger),
                      value: finger,
                      onChanged: (v) {
                        setState(() {
                          finger = v;
                        });
                      },
                    ),



                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, EraserTool(width: tempWidth, finger: finger));

                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    else return;
  }


  void _showSelectionSetupDialog( int toolIndex, GlobalKey buttonKey) {

    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    final language = AppLocalizations.of(context)!;

    if (tool is SelectionTool) {

      SelectionShape shape = tool.shape;
      //bool selectionRule = tool.selectionRule;
      bool selectionRule = ref.watch(editorSetupProvider)[editorIndex].selectionMode;
      bool finger = tool.finger;

      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      language.selection_shape,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    RadioListTile<SelectionShape>(dense: true, value: SelectionShape.lasso, groupValue: shape, title: Text(language.lasso), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<SelectionShape>(dense: true, value: SelectionShape.rect, groupValue: shape, title: Text(language.rectangle), onChanged: (v) {setState(() {shape = v!;});},),
                    //RadioListTile<SelectionShape>(dense: true, value: SelectionShape.lasso, groupValue: shape, title: Text(language.lasso), onChanged: (v) {setState(() {shape = v!;});},),

                    const Divider(),

                    Text(
                      language.selection_rule,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    SwitchListTile(
                      dense: true,
                      title: Text(language.select_on_touch),
                      subtitle: Text(language.will_select_touching),
                      value: selectionRule,
                      onChanged: (v) {
                        setState(() {
                          selectionRule = v;
                        });
                      },
                    ),

                    const Divider(),

                    Text(
                      language.input,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    SwitchListTile(
                      dense: true,
                      title: Text(language.select_with_finger),
                      value: finger,
                      onChanged: (v) {
                        setState(() {
                          finger = v;
                        });
                      },
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {

                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, SelectionTool(shape: shape, selectionRule: selectionRule, finger: finger));
                            ref.read(editorSetupProvider.notifier).setSelectionMode(editorIndex, selectionRule);

                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    else return;
  }


  void _showPenSetupDialog(int toolIndex, GlobalKey buttonKey) {

    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    final language = AppLocalizations.of(context)!;


    if (tool is PenTool) {

      PenType penType = tool.penType;
      AutoLine autoline = tool.autoLine;
      bool straightLineXYAlign = tool.straightLineXYAlign;
      bool finger = tool.finger;




      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      language.pen_type,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    RadioListTile<PenType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: PenType.normal, groupValue: penType, title: Text(language.normal), onChanged: (v) {setState(() {penType = v!;});},),
                    RadioListTile<PenType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: PenType.fountain, groupValue: penType, title: Text(language.fountain_pen), onChanged: (v) {setState(() {penType = v!;});},),

                    //TODO   VVV   REIMLEMENT ME   VVV
                    /*
                    RadioListTile<PenType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: PenType.pencil, groupValue: penType, title: Text("${language.pencil} [NOT IMPLEMENTED]"), onChanged: (v) {setState(() {penType = v!;});},),
                    RadioListTile<PenType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: PenType.marker, groupValue: penType, title: Text(language.marker), onChanged: (v) {setState(() {penType = v!;});},),
                    const Divider(),
                    Text(language.draw_straight_lines, style: TextStyle(fontWeight: FontWeight.bold),),
                    RadioListTile<AutoLine>(dense: true, visualDensity: VisualDensity(vertical: -4), value: AutoLine.disabled, groupValue: autoline, title: Text(language.disabled), onChanged: (v) {setState(() {autoline = v!;});},),
                    RadioListTile<AutoLine>(dense: true, visualDensity: VisualDensity(vertical: -4), value: AutoLine.detectStraight, groupValue: autoline, title: Text(language.auto_detect), onChanged: (v) {setState(() {autoline = v!;});},),
                    RadioListTile<AutoLine>(dense: true, visualDensity: VisualDensity(vertical: -4), value: AutoLine.hold, groupValue: autoline, title: Text(language.hold_for_line), onChanged: (v) {setState(() {autoline = v!;});},),
                    SwitchListTile(dense: true, title: Text(language.align_xy), subtitle: Text(language.lines_will_tend_to), value: straightLineXYAlign, onChanged: (v) {setState(() {straightLineXYAlign = v;});},),

                     */

                    const Divider(),

                    Text(language.input, style: TextStyle(fontWeight: FontWeight.bold),),

                    SwitchListTile(dense: true, title: Text(language.draw_with_finger), value: finger, onChanged: (v) {setState(() {finger = v;});},),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {

                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, PenTool(penType: penType, autoLine: autoline, straightLineXYAlign: straightLineXYAlign, finger: finger, ));
                            //ref.read(editorSetupProvider.notifier).setSelectionShape(editorIndex, penType);

                            //ref.read(editorSetupProvider.notifier).setSelectionMode(editorIndex, tempTouchMode);

                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

    } else {
      return;
    }
  }


  void _showShapeSetupDialog(int toolIndex, GlobalKey buttonKey) {

    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    final language = AppLocalizations.of(context)!;


    if (tool is ShapeTool) {

      ShapeShape shape = tool.shape;
      ShapeOrigin shapeOrigin = tool.shapeOrigin;
      bool snapToGrid = tool.snapToGrid;
      bool finger = tool.finger;




      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      language.shape,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    //RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.line, groupValue: shape, title: Text(language.line), onChanged: (v) {setState(() {shape = v!;});},),
                    //RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.arrow, groupValue: shape, title: Text(language.arrow), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.rect, groupValue: shape, title: Text(language.rect), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.circle, groupValue: shape, title: Text(language.circle), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.triangle, groupValue: shape, title: Text(language.triangle), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.pentagon, groupValue: shape, title: Text(language.pentagon), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.hexagon, groupValue: shape, title: Text(language.hexagon), onChanged: (v) {setState(() {shape = v!;});},),
                    RadioListTile<ShapeShape>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeShape.octagon, groupValue: shape, title: Text(language.octagon), onChanged: (v) {setState(() {shape = v!;});},),

                    const Divider(),

                    Text(language.shape_origin, style: TextStyle(fontWeight: FontWeight.bold),),

                    RadioListTile<ShapeOrigin>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeOrigin.corner, groupValue: shapeOrigin, title: Text(language.corner), onChanged: (v) {setState(() {shapeOrigin = v!;});},),
                    RadioListTile<ShapeOrigin>(dense: true, visualDensity: VisualDensity(vertical: -4), value: ShapeOrigin.center, groupValue: shapeOrigin, title: Text(language.center), onChanged: (v) {setState(() {shapeOrigin = v!;});},),

                    SwitchListTile(dense: true, title: Text(language.snap_to_grid), value: snapToGrid, onChanged: (v) {setState(() {snapToGrid = v;});},),

                    const Divider(),

                    Text(language.input, style: TextStyle(fontWeight: FontWeight.bold),),

                    SwitchListTile(dense: true, title: Text(language.draw_with_finger), value: finger, onChanged: (v) {setState(() {finger = v;});},),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {

                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, ShapeTool(shape: shape, shapeOrigin: shapeOrigin, snapToGrid: snapToGrid,finger: finger, ));
                            //ref.read(editorSetupProvider.notifier).setSelectionShape(editorIndex, penType);

                            //ref.read(editorSetupProvider.notifier).setSelectionMode(editorIndex, tempTouchMode);

                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

    } else {
      return;
    }
  }

  void _showLineSetupDialog(int toolIndex, GlobalKey buttonKey) {

    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    final language = AppLocalizations.of(context)!;


    if (tool is LineTool) {

      LineType line = tool.line;
      LineOrigin lineOrigin = tool.lineOrigin;
      bool snapToGrid = tool.snapToGrid;
      bool finger = tool.finger;




      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      language.shape,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),


                    RadioListTile<LineType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineType.line, groupValue: line, title: Text(language.line), onChanged: (v) {setState(() {line = v!;});},),
                    RadioListTile<LineType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineType.arrow, groupValue: line, title: Text(language.arrow), onChanged: (v) {setState(() {line = v!;});},),
                    //RadioListTile<LineType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineType.dotted, groupValue: line, title: Text("dotted"), onChanged: (v) {setState(() {line = v!;});},),
                    //RadioListTile<LineType>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineType.sine, groupValue: line, title: Text("sine"), onChanged: (v) {setState(() {line = v!;});},),


                    const Divider(),

                    Text(language.shape_origin, style: TextStyle(fontWeight: FontWeight.bold),),

                    RadioListTile<LineOrigin>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineOrigin.corner, groupValue: lineOrigin, title: Text(language.corner), onChanged: (v) {setState(() {lineOrigin = v!;});},),
                    RadioListTile<LineOrigin>(dense: true, visualDensity: VisualDensity(vertical: -4), value: LineOrigin.center, groupValue: lineOrigin, title: Text(language.center), onChanged: (v) {setState(() {lineOrigin = v!;});},),



                    SwitchListTile(dense: true, title: Text(language.snap_to_grid), value: snapToGrid, onChanged: (v) {setState(() {snapToGrid = v;});},),

                    const Divider(),

                    Text(language.input, style: TextStyle(fontWeight: FontWeight.bold),),

                    SwitchListTile(dense: true, title: Text(language.draw_with_finger), value: finger, onChanged: (v) {setState(() {finger = v;});},),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {

                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, LineTool(line: line, lineOrigin: lineOrigin, snapToGrid: snapToGrid,finger: finger, ));
                            //ref.read(editorSetupProvider.notifier).setSelectionShape(editorIndex, penType);

                            //ref.read(editorSetupProvider.notifier).setSelectionMode(editorIndex, tempTouchMode);

                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

    } else {
      return;
    }
  }

  void _showLaserSetupDialog(int toolIndex, GlobalKey buttonKey) {

    final language = AppLocalizations.of(context)!;
    final tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    if (tool is LaserTool) {
      final currentWidth = tool.width;

      final RenderBox buttonRenderBox =
      buttonKey.currentContext!.findRenderObject() as RenderBox;
      final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      final Size buttonSize = buttonRenderBox.size;

      double tempWidth = currentWidth;
      bool finger = tool.finger;

      bool leavaTrail = tool.leaveTrail;
      bool fadeOut = tool.fadeOut;

      double fadeOutDuration = tool.fadeOutDuration;
      if (fadeOutDuration > 20) fadeOutDuration = 20;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonPosition.dx + buttonSize.width,
          buttonPosition.dy,
        ),
        items: [
          PopupMenuItem(
            enabled: false, // verhindert, dass es direkt ausgewählt wird
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(language.laser_width),
                    Slider(
                      min: 0.1,
                      max: 10,
                      divisions: 99,
                      value: tempWidth,
                      label: "${tempWidth.round()}",
                      onChanged: (value) {
                        setState(() {
                          tempWidth = value;
                        });
                      },
                    ),
                    SizedBox(height: 4),
                    Text("${language.current} ${tempWidth.toStringAsFixed(1)}"),

                    const Divider(),

                    Text(language.fade_out_duration),
                    Slider(
                      min: 0.1,
                      max: 20,
                      divisions: 99,
                      value: fadeOutDuration,
                      label: "${fadeOutDuration.round()}",
                      onChanged: (value) {
                        setState(() {
                          fadeOutDuration = value;
                        });
                      },
                    ),
                    SizedBox(height: 4),
                    Text("${language.current} ${fadeOutDuration.toStringAsFixed(1)}s"),

                    SwitchListTile(dense: true, title: Text(language.leave_trail), value: leavaTrail, onChanged: (v) {setState(() {leavaTrail = v;});},),
                    SwitchListTile(dense: true, title: Text(language.fade_out), value: fadeOut, onChanged: (v) {setState(() {fadeOut = v;});},),

                    const Divider(),

                    Text(language.input, style: TextStyle(fontWeight: FontWeight.bold),),

                    SwitchListTile(dense: true, title: Text(language.draw_with_finger), value: finger, onChanged: (v) {setState(() {finger = v;});},),



                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(language.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(editorSetupProvider.notifier).setTool(editorIndex, toolIndex, LaserTool(width: tempWidth, finger: finger, leaveTrail: leavaTrail, fadeOut: fadeOut, fadeOutDuration: fadeOutDuration));
                            Navigator.of(context).pop();
                          },
                          child: Text(language.ok),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    else return;
  }








}


