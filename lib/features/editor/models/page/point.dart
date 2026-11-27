import 'package:flutter/widgets.dart';

/// One input point of a stroke. Immutable (D1): change a point by replacing it.
class PointModel {
  final Offset pos;
  final double width;

  const PointModel({required this.pos, required this.width});

  PointModel copyWith({Offset? pos, double? width}) =>
      PointModel(pos: pos ?? this.pos, width: width ?? this.width);

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
