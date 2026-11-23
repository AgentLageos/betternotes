import 'package:flutter/material.dart';

import 'page_model.dart';
import '../commands/command.dart';
import 'package:betternotes/core/utils/id_generator.dart';


class DocumentModel {
  List<PageModel> pages;
  String pathToFile;
  int currentPageIndex;

  Color docBackgroundColor;
  List<Command> commands;
  int commandIndex;
  int maxAmountCommands;
  int docID;

  final PageModel defaultPage;




  final DateTime created;
  final String author;
  final String title;

  double placeholderHeight;

  List<double> pageHeights;

  List<int> pageList;






  DocumentModel({
    required this.pages,
    this.pathToFile = '',         //empty until the document is loaded from / saved to a file
    this.currentPageIndex = 0,
    this.docBackgroundColor = Colors.white,
    this.commandIndex = 0,
    this.maxAmountCommands = 10,
    List<Command>? commands, // ← optional
    PageModel? defaultPage,
    int? docID,

    required this.created,
    required this.author,
    required this.title,
    double? placeholderHeight,
    //int? totalPages,
    List<double>? pageHeights,
    List<int>? pageList

  }) : commands = commands ?? [],  docID = docID ?? IdGenerator.next(),
        defaultPage = defaultPage ?? PageModel(strokes: [], backgroundStrokes: [], images: [], pageWidth: 210, pageHeight: 297, pageColor: Colors.white, tiles: []),
        placeholderHeight = placeholderHeight ?? 0.0,
        pageHeights = pageHeights ?? [0],
        pageList = pageList ?? []
  ;

  DocumentModel copyWith({
    List<PageModel>? pages,
    int? currentPageIndex,
    String? pathToFile,
    bool? newPageAdded,
    Color? docBackgroundColor,
    int? commandIndex,
    List<Command>? commands,
    int? maxAmountCommands,
    int? docID,
    PageModel? defaultPage,
    DateTime? created,
    String? author,
    String? title,
    double? placeholderHeight,
    //int? totalPages,
    List<double>? pageHeights,
    List<int>? pageList
  }) {
    return DocumentModel(
      pages: pages ?? this.pages, // keep the old list if no new one is given
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      pathToFile: pathToFile ?? this.pathToFile,
      docBackgroundColor: docBackgroundColor ?? this.docBackgroundColor,
      commandIndex: commandIndex ?? this.commandIndex,
      commands: commands ?? this.commands,
      maxAmountCommands: maxAmountCommands ?? this.maxAmountCommands,
      docID: docID ?? this.docID,
      defaultPage: defaultPage ?? this.defaultPage,

      created: created ?? this.created,
      author: author ?? this.author,
      title: title ?? this.title,
      placeholderHeight: placeholderHeight ?? this.placeholderHeight,
      pageHeights: pageHeights ?? this.pageHeights,
      pageList: pageList ?? this.pageList


    );
  }






  /// Metadata stored in the `.bnf` file (the repository adds `modified`).
  Map<String, dynamic> toMetadata() {
    return {
      'title': title,
      'author': author,
      'created': created.toIso8601String(),
      'defaultPage': defaultPage.toJson(),
      'pageHeights': pageHeights,
      'pageList': pageList,
    };
  }
}