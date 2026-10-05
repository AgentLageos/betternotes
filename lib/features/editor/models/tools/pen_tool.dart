import 'dart:ui';

import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:flutter/material.dart';


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





class PenTool extends Tool{
  Color color;
  double width;

  PenType penType;

  //bool finger; //if drawing with finger is enabled
  //bool pencil; //if pen draws strokes with a pencilpattern
  //bool marker; //if the pen acts like a marker
  AutoLine autoLine; //if and how the pen is able to create straight lines: "DISABLED" : no straight lines, "hold": straight line will be created when puttingpen down and holding still, "detectStraight": draws line when handdrawn line is straight enough
  bool straightLineXYAlign; //when enabled, straight that are almost parallel to x or y axis will be aligned, only works when autoLine is enabled


  PenTool({
    Color? color,
    double? width,
    bool? finger,
    //bool? pencil,
    //bool? marker,
    PenType? penType,
    AutoLine? autoLine,
    bool? straightLineXYAlign,
    int? toolID,
  })
      : color = color ?? Colors.black,
        width = width ?? 0.4,
        //finger = finger ?? false,
        //pencil = pencil ?? false,
        //marker = marker ?? false,
        penType = penType ?? PenType.normal,
        autoLine = autoLine ?? AutoLine.disabled,
        straightLineXYAlign = straightLineXYAlign ?? true,
        super(finger: finger, toolID: toolID)
  ;

  PenTool copyWith({
    Color? color,
    double? width,
    bool? finger,
    //bool? pencil,
    //bool? marker,
    PenType? penType,
    AutoLine? autoLine,
    bool? straightLineXYAlign,
    int? toolID
  }) {
    return PenTool(
        color: color ?? this.color,
        width: width ?? this.width,
        finger: finger ?? this.finger,
        //pencil: pencil ?? this.pencil,
        //marker: marker ?? this.marker,
        penType: penType ?? this.penType,
        autoLine: autoLine ?? this.autoLine,
        straightLineXYAlign: straightLineXYAlign ?? this.straightLineXYAlign,
        toolID: toolID ?? this.toolID

    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'color': color.value,
    'width': width,
    'finger': finger,
    //'pencil': pencil,
    //'marker': marker,
    'penType': penType.toJson(),
    'autoLine': autoLine.toJson(),
    'straightLineXYAlign': straightLineXYAlign,
  };

  factory PenTool.fromJson(Map<String, dynamic> json) => PenTool(
    color: Color(json['color']),
    width: json['width'],
    finger: json['finger'],
    //pencil: json['pencil'],
    //marker: json['marker'],
    penType: PenTypeExtension.fromJson(json['penType']),
    autoLine: AutoLineExtension.fromJson(json['autoLine']),
    straightLineXYAlign: json['straightLineXYAlign'],
  );

  @override
  String get type => 'PenTool';

}