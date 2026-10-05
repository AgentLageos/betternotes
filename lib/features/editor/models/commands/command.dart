import 'package:betternotes/core/utils/id_generator.dart';

abstract class Command {
  final int commandID;

  Command({
    int? commandID,
  }) :  commandID = commandID ?? IdGenerator.next();

}