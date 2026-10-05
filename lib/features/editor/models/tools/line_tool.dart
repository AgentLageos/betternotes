import 'dart:ui';

import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:flutter/material.dart';



enum LineType {
  line,
  arrow,
  dotted,
  sine,

}
extension LineTypeExtension on LineType {
  String toJson() => name;
  static LineType fromJson(String value) => LineType.values.firstWhere((e) => e.name == value);
}

enum LineOrigin {
  corner,
  center,
}
extension LineOriginExtension on LineOrigin {
  String toJson() => name;
  static LineOrigin fromJson(String value) => LineOrigin.values.firstWhere((e) => e.name == value);
}





class LineTool extends Tool{
  Color iconColor;
  double width;
  LineType line;
  LineOrigin lineOrigin;
  bool snapToGrid;



  LineTool({
    Color? iconColor,
    double? width,
    bool? finger,
    LineType? line,
    LineOrigin? lineOrigin,
    bool? snapToGrid,
    int? toolID,
  })
      : iconColor = iconColor ?? Colors.greenAccent,
        width = width ?? 0.4,
        line = line ?? LineType.line,
        lineOrigin = lineOrigin ?? LineOrigin.corner,
        snapToGrid = snapToGrid ?? false,
        super(finger: finger, toolID: toolID)
  ;

  LineTool copyWith({
    Color? iconColor,
    double? width,
    bool? finger,
    LineType? shape,
    LineOrigin? shapeOrigin,
    bool? snapToGrid,
    int? toolID
  }) {
    return LineTool(
        iconColor: iconColor ?? this.iconColor,
        width: width ?? this.width,
        finger: finger ?? this.finger,
        line: line ?? this.line,
        lineOrigin: shapeOrigin ?? this.lineOrigin,
        snapToGrid: snapToGrid ?? this.snapToGrid,
        toolID: toolID ?? this.toolID

    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'iconColor': iconColor.value,
    'width': width,
    'finger': finger,
    'line': line.toJson(),
    'lineOrigin': lineOrigin.toJson(),
    'snapToGrid': snapToGrid,
  };

  factory LineTool.fromJson(Map<String, dynamic> json) => LineTool(
    iconColor: Color(json['iconColor']),
    width: json['width'],
    finger: json['finger'],
    line: LineTypeExtension.fromJson(json['line']),
    lineOrigin: LineOriginExtension.fromJson(json['lineOrigin']),
    snapToGrid: json['snapToGrid'],
  );

  @override
  String get type => 'LineTool';

}