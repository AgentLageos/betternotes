import 'dart:ui';

import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:flutter/material.dart';



enum ShapeShape {
  line,
  arrow,
  rect,
  circle,
  triangle,
  pentagon,
  hexagon,
  octagon,
}
extension ShapeExtension on ShapeShape {
  String toJson() => name;
  static ShapeShape fromJson(String value) => ShapeShape.values.firstWhere((e) => e.name == value);
}

enum ShapeOrigin {
  corner,
  center,
}
extension ShapeOriginExtension on ShapeOrigin {
  String toJson() => name;
  static ShapeOrigin fromJson(String value) => ShapeOrigin.values.firstWhere((e) => e.name == value);
}





class ShapeTool extends Tool{
  Color iconColor;
  double width;
  ShapeShape shape;
  ShapeOrigin shapeOrigin;
  bool snapToGrid;



  ShapeTool({
    Color? iconColor,
    double? width,
    bool? finger,
    ShapeShape? shape,
    ShapeOrigin? shapeOrigin,
    bool? snapToGrid,
    int? toolID,
  })
      : iconColor = iconColor ?? Colors.greenAccent,
        width = width ?? 0.4,
        shape = shape ?? ShapeShape.rect,
        shapeOrigin = shapeOrigin ?? ShapeOrigin.corner,
        snapToGrid = snapToGrid ?? false,
        super(finger: finger, toolID: toolID)
  ;

  ShapeTool copyWith({
    Color? iconColor,
    double? width,
    bool? finger,
    ShapeShape? shape,
    ShapeOrigin? shapeOrigin,
    bool? snapToGrid,
    int? toolID
  }) {
    return ShapeTool(
        iconColor: iconColor ?? this.iconColor,
        width: width ?? this.width,
        finger: finger ?? this.finger,
        shape: shape ?? this.shape,
        shapeOrigin: shapeOrigin ?? this.shapeOrigin,
        snapToGrid: snapToGrid ?? this.snapToGrid,
        toolID: toolID ?? this.toolID

    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'iconColor': iconColor.value,
    'width': width,
    'finger': finger,
    'shape': shape.toJson(),
    'shapeOrigin': shapeOrigin.toJson(),
    'snapToGrid': snapToGrid,
  };

  factory ShapeTool.fromJson(Map<String, dynamic> json) => ShapeTool(
    iconColor: Color(json['iconColor']),
    width: json['width'],
    finger: json['finger'],
    shape: ShapeExtension.fromJson(json['shape']),
    shapeOrigin: ShapeOriginExtension.fromJson(json['shapeOrigin']),
    snapToGrid: json['snapToGrid'],
  );

  @override
  String get type => 'ShapeTool';

}