import 'dart:ui';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/tools/eraser_tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/selection_tool.dart';
import 'package:flutter/material.dart';

import '../tools/tool.dart';
import '../tools/shape_tool.dart';



//import 'command/command.dart';
//import 'package:betternotes/global_variables/functions/id_generator.dart';

class EditorSetup {
  final List<int> selectorPools;
  //final List<int> toolsOld;
  final List<Tool> tools;
  final List<double> widths;
  final List<Color> colors;

  final Color selectionColor;         //what color the selection area will have
  final int selectionShape;           //0=freeform selection; 1=rectangular selection
  final bool selectionMode;            //0=select when inside; 1=select when touching

  final int toolIndex;
  final int widthIndex;
  final int colorIndex;

  final double eraserWidth;

  final List<double> spaces;    //how much space each pool gets. should sum up to ten. (i think)

  final PageModel defaultPage;


  EditorSetup({
    List<int>? selectorPools,
    //List<int>? toolsOld,
    List<Tool>? tools,
    List<double>? widths,
    List<Color>? colors,
    Color? selectionColor,
    int? selectionShape,
    bool? selectionMode,
    int? toolIndex,
    int? widthIndex,
    int? colorIndex,
    double? eraserWidth,
    List<double>? spaces,
    PageModel? defaultPage,
  }) : selectorPools = selectorPools ?? [0,1,2,3],
        //toolsOld= toolsOld ?? [0,1,2,3,4,8,8,8],
        tools = tools ?? [PenTool(), EraserTool(), SelectionTool(), ShapeTool(), LaserTool()],
        widths = widths ?? [0.4, 1.2, 4.0],
        colors = colors ?? [Colors.black, Colors.blue, Colors.red, Colors.green, Colors.yellow],
        selectionColor = selectionColor ?? Colors.blue,
        selectionShape = selectionShape ?? 0,
        selectionMode = selectionMode ?? false,
        toolIndex = toolIndex ?? 0,
        widthIndex = widthIndex ?? 0,
        colorIndex = colorIndex ?? 0,
        spaces = spaces ?? [0.4, 0.25, 0.25,0.1],
        eraserWidth = eraserWidth ?? 4.0,
        defaultPage = defaultPage ?? PageModel(strokes: [], pageWidth: 210, pageHeight: 297, backgroundStrokes: [], images: [], pageColor: Colors.white, tiles: [])

  ;
      //selectorPools ?? [ToolSelector(tools: [0, 1, 2]), WidthSelector(widths: [0.4, 1.2, 4.0]), ColorSelector(colors: [Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow])];

  EditorSetup copyWith({
    List<int>? selectorPools,
    //List<int>? toolsOld,
    List<Tool>? tools,
    List<double>? widths,
    List<Color>? colors,
    Color? selectionColor,
    int? selectionShape,
    bool? selectionMode,
    int? toolIndex,
    int? widthIndex,
    int? colorIndex,
    double? eraserWidth,
    List<double>? spaces,
    PageModel? defaultPage,


  }) {
    return EditorSetup(
      selectorPools: selectorPools ?? this.selectorPools,
      //toolsOld: toolsOld ?? this.toolsOld,
      tools : tools ?? this.tools,
      widths: widths?? this.widths,
      colors: colors ?? this.colors,
      selectionColor: selectionColor ?? this.selectionColor,
      selectionShape: selectionShape ?? this.selectionShape,
      selectionMode: selectionMode ?? this.selectionMode,
      toolIndex: toolIndex ?? this.toolIndex,
      widthIndex: widthIndex ?? this.widthIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      eraserWidth: eraserWidth ?? this.eraserWidth,
      spaces: spaces ?? this.spaces,
      defaultPage: defaultPage ?? this.defaultPage,
    );
  }
}
