import 'package:betternotes/core/utils/id_generator.dart';

abstract class Tool {
  final int toolID;
  bool finger;

  Tool({
    bool? finger,
    int? toolID,
  }) :  toolID = toolID ?? IdGenerator.next(),
        finger = finger ?? false
    ;

  String get type;

  Map<String, dynamic> toJson();

}