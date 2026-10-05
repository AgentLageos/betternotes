import 'package:betternotes/features/editor/models/tools/tool.dart';

enum Shape {
  circle,
  rect,
}


extension ShapeExtension on Shape {
  String toJson() => name;
  static Shape fromJson(String value) =>
      Shape.values.firstWhere((e) => e.name == value);
}



class EraserTool extends Tool{

  double width;

  Shape shape;


  EraserTool({
    double? width,
    Shape? shape,
    bool? finger,

    int? toolID,
  })
      : width = width ?? 4.0,
        shape = shape ?? Shape.circle,
        super(finger: finger, toolID: toolID)
  ;

  EraserTool copyWith({
    double? width,
    Shape? shape,
    bool? finger,
    int? toolID
  }) {
    return EraserTool(
        width: width ?? this.width,
        shape: shape ?? this.shape,
        finger: finger ?? this.finger,
        toolID: toolID ?? this.toolID
    );
  }






  Map<String, dynamic> toJson() => {
    'type': type,
    'width': width,
    'finger': finger,
    'shape': shape.toJson(),
  };

  factory EraserTool.fromJson(Map<String, dynamic> json) => EraserTool(
    width: json['width'],
    finger: json['finger'],
    shape: ShapeExtension.fromJson(json['shape']),
  );

  @override
  String get type => 'EraserTool';

}