import 'package:flutter/cupertino.dart';
import 'command.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';


class ModifyPagesCommand extends Command {
  final List<PageModel> addPages;
  final List<int> addPageIndexes;
  final List<PageModel> removePages;
  final List<int> removePageIndexes;


  ModifyPagesCommand({
    required this.addPages,
    required this.addPageIndexes,
    required this.removePages,
    required this.removePageIndexes,
    int? commandID,
  }): super(commandID: commandID);

}