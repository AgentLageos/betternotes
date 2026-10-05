import 'dart:ui';

import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:flutter/material.dart';

/*
enum AutoLine {
  disabled,
  hold,
  detectStraight,
}
extension AutoLineExtension on AutoLine {
  String toJson() => name;
  static AutoLine fromJson(String value) => AutoLine.values.firstWhere((e) => e.name == value);
}

enum PenType {
  normal,
  fountain,
  pencil,
  marker,
}
extension PenTypeExtension on PenType {
  String toJson() => name;
  static PenType fromJson(String value) => PenType.values.firstWhere((e) => e.name == value);
}

 */


class LaserTool extends Tool{
  Color color;
  Color iconColor;
  double width;
  bool leaveTrail; //when enabled, the laser pointer will leave a trail that disappears some time after
  bool fadeOut;
  double fadeOutDuration;

  LaserTool({
    Color? color,
    Color? iconColor,
    double? width,
    bool? finger,
    bool? leaveTrail,
    bool? fadeOut,
    double? fadeOutDuration,
    int? toolID,
  })
      : color = color ?? Colors.red,
        iconColor = iconColor ?? Colors.black,
        width = width ?? 0.4,
        leaveTrail = leaveTrail ?? true,
        fadeOut = fadeOut ?? true,
        fadeOutDuration = fadeOutDuration ?? 4,
        super(finger: finger, toolID: toolID)
  ;

  LaserTool copyWith({
    Color? color,
    Color? iconColor,
    double? width,
    bool? finger,
    bool? leaveTrail,
    bool? fadeOut,
    double? fadeOutDuration,
    int? toolID
  }) {
    return LaserTool(
        color: color ?? this.color,
        iconColor: iconColor ?? this.iconColor,
        width: width ?? this.width,
        finger: finger ?? this.finger,
        leaveTrail: leaveTrail ?? this.leaveTrail,
        fadeOut: fadeOut ?? this.fadeOut,
        fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
        toolID: toolID ?? this.toolID

    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'color': color.value,
    'iconColor': iconColor.value,
    'width': width,
    'finger': finger,
    'leaveTrail': leaveTrail,
    'fadeOut': fadeOut,
    'fadeOutDuration': fadeOutDuration,
  };

  factory LaserTool.fromJson(Map<String, dynamic> json) => LaserTool(
    color: Color(json['color']),
    iconColor: Color(json['iconColor']),
    width: json['width'],
    finger: json['finger'],
    leaveTrail: json['leaveTrail'],
    fadeOut: json['fadeOut'],
    fadeOutDuration:  json['fadeOutDuration'],
  );

  @override
  String get type => 'LaserTool';

}