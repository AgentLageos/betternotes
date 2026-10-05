import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:flutter/material.dart';

enum SelectionShape {
  lasso,
  rect,

}

extension SelectionShapeExtension on SelectionShape {
  String toJson() => name;
  static SelectionShape fromJson(String value) =>
      SelectionShape.values.firstWhere((e) => e.name == value);
}



class SelectionTool extends Tool{


  SelectionShape shape;
  bool selectionRule;     //when =1 selects everything the selection touches, otherwise only selects objects that are fully inside selection area
  Color selectionColor;


  SelectionTool({
    SelectionShape? shape,
    bool? selectionRule,
    Color? selectionColor,
    bool? finger,
    int? toolID,
  })
      :shape = shape ?? SelectionShape.lasso,
      selectionRule = selectionRule ?? false,
      selectionColor = selectionColor ?? Colors.blue,
        super(toolID: toolID, finger: finger)
  ;

  SelectionTool copyWith({
    SelectionShape? shape,
    bool? selectionRule,
    Color? selectionColor,
    bool? finger,
    int? toolID,
  }) {
    return SelectionTool(
        shape: shape ?? this.shape,
        selectionRule: selectionRule ?? this.selectionRule,
        selectionColor: selectionColor ?? this.selectionColor,
        finger: finger ?? this.finger,
        toolID: toolID ?? this.toolID
    );
  }



  Map<String, dynamic> toJson() => {
    'type': type,
    'shape': shape.toJson(),
    'selectionRule': selectionRule,
    'finger' : finger,
    'selectionColor': selectionColor.value,
  };

  factory SelectionTool.fromJson(Map<String, dynamic> json) => SelectionTool(
    shape: SelectionShapeExtension.fromJson(json['shape']),
    finger: json['finger'],
    selectionRule: json['selctionRule'],
    selectionColor: Color(json['selectionColor'])
  );


  @override
  String get type => 'SelectionTool';



}