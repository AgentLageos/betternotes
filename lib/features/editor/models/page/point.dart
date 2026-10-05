import 'package:flutter/widgets.dart';

class PointModel {
  Offset pos;
  final double width;


  PointModel({required this.pos, required this.width});

  PointModel copy() {
    return PointModel(
      pos: pos,
      width: width
    );
  }


  Map<String, dynamic> toJson() => {
    'dx': pos.dx,
    'dy': pos.dy,
    'width': width,
  };

  factory PointModel.fromJson(Map<String, dynamic> json) => PointModel(
    pos: Offset(json['dx']?.toDouble() ?? 0.0, json['dy']?.toDouble() ?? 0.0,),
    width: json['width']?.toDouble() ?? 0.0,
  );






}