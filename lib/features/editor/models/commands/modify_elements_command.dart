import '../page/image_model.dart';
import 'command.dart';
//import '../../editor/document/model[unused]/stroke[unused].dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';


class ModifyElementsCommand extends Command {
  final List<Stroke> addedStrokes;
  final List<ImageModel> addedImages;
  final List<Stroke> removedStrokes;
  final List<ImageModel> removedImages;
  final int pageID;

  ModifyElementsCommand({
    required this.addedStrokes,
    required this.addedImages,
    required this.removedStrokes,
    required this.removedImages,
    required this.pageID,
    int? commandID,
  }): super(commandID: commandID);

}