import 'package:betternotes/features/editor/models/tools/eraser_tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/selection_tool.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/global_providers.dart';
import '../../../models/tools/line_tool.dart';
import '../../../models/tools/shape_tool.dart';
import 'package:betternotes/features/editor/models/tools/tool.dart';


final editorIndex = 0;



class ToolButton extends ConsumerWidget {   //widget for displaying tools

  final int toolIndex;

  const ToolButton({Key? key, required this.toolIndex}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {


    final backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.4);
    final iconColor = Theme.of(context).colorScheme.onSurface;




    Tool tool = ref.watch(editorSetupProvider)[editorIndex].tools[toolIndex];

    if(tool is PenTool) {

      late IconData icon;
      if (tool.penType == PenType.fountain) icon = Icons.brush;
      else if(tool.penType == PenType.pencil) icon = Icons.edit_outlined;
      else if(tool.penType == PenType.marker) icon = Icons.drive_file_rename_outline_sharp;
      else icon = Icons.edit;

      if (tool.finger == true) icon = Icons.front_hand;




      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      );
    }


    else if(tool is EraserTool) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          Icons.edit_off,
          color: iconColor,
        ),
      );
    }
    else if(tool is EraserTool) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          Icons.edit_off,
          color: iconColor,
        ),
      );
    }
    else if (tool is SelectionTool) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          Icons.crop_free,
          color: iconColor,
        ),
      );
    }
    else if (tool is ShapeTool) {


      late IconData icon;
      if (tool.shape == ShapeShape.line) icon = Icons.horizontal_rule;
      else if(tool.shape == ShapeShape.arrow) icon = Icons.arrow_right_alt_rounded;
      else if(tool.shape == ShapeShape.rect) icon = Icons.crop_3_2;
      else if(tool.shape == ShapeShape.circle) icon = Icons.circle_outlined;
      else if(tool.shape == ShapeShape.triangle) icon = Icons.change_history_rounded;
      else icon = Icons.crop_3_2;

      if (tool.finger == true) icon = Icons.front_hand;


      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      );
    }
    else if (tool is LineTool) {


      late IconData icon;
      if (tool.line == LineType.line) icon = Icons.horizontal_rule;
      else if(tool.line == LineType.arrow) icon = Icons.arrow_right_alt_rounded;
      else if(tool.line == LineType.dotted) icon = Icons.more_horiz_outlined;
      else if(tool.line == LineType.sine) icon = Icons.show_chart;
      //else if(tool.line == LineType.triangle) icon = Icons.change_history_rounded;
      else icon = Icons.horizontal_rule;

      if (tool.finger == true) icon = Icons.front_hand;


      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      );
    }



    else if (tool is LaserTool){

      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          Icons.light_mode_outlined,
          color: iconColor,
        ),
      );
    }


    else{

      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          Icons.edit,
          color: iconColor,
        ),
      );
    }


  }
}