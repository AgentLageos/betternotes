import 'package:flutter/material.dart';

import 'page_model.dart';
import '../commands/command.dart';
import 'package:betternotes/core/utils/id_generator.dart';


/// One open document. Immutable (D1): all fields are final, lists are unmodifiable, changes go
/// through [copyWith].
///
/// [pageList] and [pageHeights] describe the whole document; [pages] holds only the loaded window
/// around [currentPageIndex] (other pages are not in memory, see `DocumentsNotifier`).
class DocumentModel {
  final List<PageModel> pages;
  final String pathToFile;
  final int currentPageIndex;

  final Color docBackgroundColor;

  /// Undo history; [commandIndex] commands are done, the rest can be redone.
  final List<Command> commands;
  final int commandIndex;
  final int maxAmountCommands;
  final int docID;

  final PageModel defaultPage;

  final DateTime created;
  final String author;
  final String title;

  /// Height of the space above the loaded window (pages before it are not built).
  final double placeholderHeight;

  /// Page heights in mm, same order as [pageList].
  final List<double> pageHeights;

  /// IDs of all pages in document order.
  final List<int> pageList;

  DocumentModel({
    required List<PageModel> pages,
    this.pathToFile = '',         //empty until the document is loaded from / saved to a file
    this.currentPageIndex = 0,
    this.docBackgroundColor = Colors.white,
    this.commandIndex = 0,
    this.maxAmountCommands = 10,
    List<Command>? commands,
    PageModel? defaultPage,
    int? docID,
    required this.created,
    required this.author,
    required this.title,
    double? placeholderHeight,
    List<double>? pageHeights,
    List<int>? pageList,
  }) : pages = List.unmodifiable(pages),
        commands = List.unmodifiable(commands ?? const <Command>[]),
        docID = docID ?? IdGenerator.next(),
        defaultPage = defaultPage ?? PageModel(pageWidth: 210, pageHeight: 297, pageColor: Colors.white),
        placeholderHeight = placeholderHeight ?? 0.0,
        pageHeights = List.unmodifiable(pageHeights ?? const [0.0]),
        pageList = List.unmodifiable(pageList ?? const <int>[]);

  DocumentModel copyWith({
    List<PageModel>? pages,
    int? currentPageIndex,
    String? pathToFile,
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
    List<double>? pageHeights,
    List<int>? pageList,
  }) {
    return DocumentModel(
      pages: pages ?? this.pages,
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
      pageList: pageList ?? this.pageList,
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