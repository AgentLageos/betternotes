import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:betternotes/core/bnf/bnf_repository.dart';
import 'package:betternotes/features/editor/data/document_file.dart';
import 'package:betternotes/features/editor/models/commands/modify_elements_command.dart';
import 'package:betternotes/features/editor/models/commands/modify_pages_command.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';

import '../../../core/utils/isolates/initialize_tiles.dart' as iso;
import '../../../core/utils/id_generator.dart';
import '../models/commands/command.dart';

import '../models/page/image_model.dart';

import '../models/page/tile.dart';
import '../rendering/page_tiles.dart';


class DocumentsNotifier extends Notifier<List<DocumentModel>> {

  int currentDocIndex = 0;

  /// ID of the document currently shown in the editor.
  /// Only one document is open at a time for now; tabs will replace this (P4-03).
  int get currentDocID => state[currentDocIndex].docID;

  /// Position of the document with [docID] in [state], or -1 if it is not open.
  int _docIndexOf(int docID) => state.indexWhere((d) => d.docID == docID);

  final Map<int, int> _requestIds = {};



  @override
  List<DocumentModel> build() => [DocumentModel(pages: [], created: DateTime.now(), author: '', title: '', )];

  Future<void> setAllHeights(int docID, double value) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    final newPages = oldDoc.pages
        .map((page) => page.copyWith(pageHeight: value))
        .toList();

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;

    await initializeAllPageTiles(oldDoc.docID);
  }

  void setPageWidth(int docID, int pageIndex, double value) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];    //copy old list

    final oldDoc = newDocuments[docIndex];

    final newPages = [
      for (int i = 0; i < oldDoc.pages.length; i++)
        if (i == pageIndex)
          oldDoc.pages[i].copyWith(pageWidth: value)
        else
          oldDoc.pages[i],
    ];

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;
  }

  Future<void> setAllWidths(int docID, double value) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    final newPages = oldDoc.pages
        .map((page) => page.copyWith(pageWidth: value))
        .toList();

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;

    await initializeAllPageTiles(oldDoc.docID);
  }


  void setDefaultPage(int docID, PageModel newDefaultPage) {
    List<DocumentModel> docs = [...state];
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;
    docs[docIndex] = docs[docIndex].copyWith(defaultPage: newDefaultPage);
    state = docs;

  }

  /// Adds and removes strokes/images on page [pageID] and records it for undo.
  /// Works on pages outside the loaded window too (they are read from and saved to the file).
  Future<void> modifyElements(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<ImageModel> removeImages) async {
    final page = await _currentPage(docID, pageID);
    if (page == null) {
      print("documents_notifier: modifyElements: page $pageID not found");
      return;
    }

    addStrokes = [for (final s in addStrokes) s.frozen()];     //the command and the page share these
    final removeStrokes = page.strokes.where((s) => removeStrokeIDs.contains(s.strokeID)).toList();
    final List<int>removeImageIDs = removeImages.map((s) => s.imageID).toList();

    addCommands(docID, [ModifyElementsCommand(addedStrokes: addStrokes, addedImages: addImages, removedStrokes: removeStrokes, removedImages: removeImages, pageID: pageID)]);
    await modifyElementsExecute(docID, pageID, addStrokes, addImages, removeStrokeIDs, removeImageIDs);
  }

  /// Applies a stroke/image change to page [pageID] without recording it (used by undo/redo).
  ///
  /// The change is idempotent: elements are removed by ID, and added elements replace elements
  /// with the same ID. That allows applying it to the file and, if the page got loaded meanwhile,
  /// to the loaded window as well.
  Future<void> modifyElementsExecute(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<int> removeImageIDs) async {
    final addedStrokeIDs = {for (final s in addStrokes) s.strokeID};
    final addedImageIDs = {for (final i in addImages) i.imageID};
    PageModel apply(PageModel page) => page.copyWith(
      images: [...page.images.where((img) => !removeImageIDs.contains(img.imageID) && !addedImageIDs.contains(img.imageID)), ...addImages],
      strokes: [...page.strokes.where((stroke) => !removeStrokeIDs.contains(stroke.strokeID) && !addedStrokeIDs.contains(stroke.strokeID)), ...addStrokes],
    );

    if (_loadedPage(docID, pageID) == null) {
      // Not in the loaded window: change the stored page.
      final page = await _currentPage(docID, pageID);
      if (page == null) {
        print("documents_notifier: modifyElementsExecute: page $pageID not found");
        return;
      }
      await saveDoc(docID, [apply(page)]);
    }

    final loaded = _loadedPage(docID, pageID);
    if (loaded != null) {
      _replacePage(docID, apply(loaded));
      await updatePage(docID, pageID, addStrokes, removeStrokeIDs);
    }
  }

  /// Page [pageID] if it is loaded (in the window and not a placeholder), otherwise null.
  PageModel? _loadedPage(int docID, int pageID) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return null;
    final page = state[docIndex].pages.where((p) => p.pageID == pageID).firstOrNull;
    return page == null || page.isTemp ? null : page;
  }

  /// Current version of page [pageID]: the loaded one, or the one stored in the file.
  /// Waits for a page of the window that is still loading. Returns null if there is no such page.
  Future<PageModel?> _currentPage(int docID, int pageID) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return null;
    if (state[docIndex].pages.any((p) => p.pageID == pageID && p.isTemp)) {
      await updateIsolatedPages(docID);
    }
    return _loadedPage(docID, pageID) ?? (await loadPages(docID, [pageID])).firstOrNull;
  }

  Future<void> modifyPages(int docID, List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async{

    final doc = [...state].firstWhere((d) => d.docID == docID);

    // Give added pages fresh IDs if their ID is already in use, so the command stored for
    // undo/redo and the state contain the same IDs.
    addPages = _withUniquePageIDs(doc, addPages);

    // Remember where each removed page was in pageList (the whole document, not the loaded
    // window in doc.pages), so undo re-inserts it at the same position.
    final removePages = <PageModel>[];
    final removePageIndexes = <int>[];
    for (final id in removePageIDs) {
      final position = doc.pageList.indexOf(id);
      if (position == -1) continue;
      final page = await _currentPage(docID, id);        //loaded or read from the file, for undo
      if (page == null) continue;
      removePages.add(page);
      removePageIndexes.add(position);
    }

    addCommands(docID, [ModifyPagesCommand(addPages: addPages, addPageIndexes: addPageIndexes,removePages: removePages, removePageIndexes: removePageIndexes)]);
    await modifyPagesExecute(docID, addPages, addPageIndexes, removePageIDs);


  }

  Future<void> modifyPagesExecute(int docID, List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async {

    final doc = [...state].firstWhere((d) => d.docID == docID);

    List<PageModel> pages = [];
    pages.addAll(doc.pages);
    addPages = _withUniquePageIDs(doc, addPages);         //duplicate page IDs cause duplicate widget keys (red screen)
    print("documents_notifier: modifyPagesExecute: add ${addPages.map((p) => p.pageID).toList()} at $addPageIndexes, remove $removePageIDs, pages: ${doc.pageList.length}");

    // Work on copies; the lists in doc are shared with older states and the undo history.
    final List<double> pageHeights = [...doc.pageHeights];
    List<int> pageList = [...doc.pageList];

    print("documents_notifier: modifyPagesExecute: ${doc.pageList}");

    // addPageIndexes are positions in pageList (the whole document). doc.pages is only the loaded
    // window, so the page is just appended there; setCurrentPageIndex below rebuilds the window in
    // pageList order (and saves pages that end up outside of it).
    for (int i = 0; i<addPageIndexes.length; i++) {
      final position = addPageIndexes[i].clamp(0, pageList.length);
      pages.add(addPages[i]);
      pageHeights.insert(position, addPages[i].pageHeight);
      pageList.insert(position, addPages[i].pageID);
    }

    print("documents_notifier: modifyPagesExecute: $pageList");


    // skip IDs that are not in the document.
    final indices = removePageIDs
        .map((id) => pageList.indexOf(id))
        .where((index) => index != -1)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in indices) {
      pageHeights.removeAt(index);
    }
    pages = pages.where((page) => !removePageIDs.contains(page.pageID)).toList();
    pageList = pageList.where((id) => !removePageIDs.contains(id)).toList();



    state = [
      for (int i = 0; i < state.length; i++)
        if (state[i].docID == docID)
          state[i].copyWith(
            pages: pages,
            pageList: pageList,
            pageHeights: pageHeights
          )
        else state[i]
    ];

    final currentPage = doc.currentPageIndex.clamp(0, pageList.isEmpty ? 0 : pageList.length - 1);
    await setCurrentPageIndex(docID, currentPage);

  }


  /// Returns [addPages] with a new ID for every page whose ID already exists in [doc]
  /// (loaded or not) or appears earlier in [addPages].
  List<PageModel> _withUniquePageIDs(DocumentModel doc, List<PageModel> addPages) {
    final usedIDs = {...doc.pageList, ...doc.pages.map((p) => p.pageID)};
    return [
      for (final p in addPages)
        if (usedIDs.add(p.pageID))
          p
        else
          () {
            final newPage = p.copyWith(pageID: IdGenerator.next());
            usedIDs.add(newPage.pageID);
            print("documents_notifier: _withUniquePageIDs: duplicate page ID ${p.pageID}, new ID ${newPage.pageID}");
            return newPage;
          }(),
    ];
  }

  void clearDoc(int docID) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;

    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    ref.read(pageTilesProvider.notifier).remove(oldDoc.pages.map((p) => p.pageID));
    newDocuments[docIndex] = oldDoc.copyWith(pages: []);

    state = newDocuments;


  }

  final lazyLoadRange = 1;
  final distanceBetweenPages = 12;

  Future<void> setCurrentPageIndex(int docID, int currentPage) async {

    List<DocumentModel> documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;         //document was closed
    DocumentModel doc = documents[docIndex];


    int lowerIndex = currentPage - lazyLoadRange;
    if (lowerIndex < 0) lowerIndex = 0;
    int upperIndex = currentPage + lazyLoadRange;
    if (upperIndex > doc.pageHeights.length-1) upperIndex = doc.pageHeights.length-1;



    List<int> oldPageIDs = doc.pages.map((page) => page.pageID).toList();
    List<int> newPageIDs = [];

    List<PageModel> newPages = [];

    for (int i = currentPage-lazyLoadRange; i<currentPage+lazyLoadRange+1; i++){      //adding new pages
      if(i>=0 && i<doc.pageList.length) {
        newPageIDs.add(doc.pageList[i]);
        if(!oldPageIDs.contains(doc.pageList[i])) {
          newPages.add(PageModel(isTemp: true, pageID: doc.pageList[i]));
        } else {
          newPages.add(doc.pages.firstWhere((p) => p.pageID == doc.pageList[i]));
        }
      }
    }

    List<PageModel> removePages = doc.pages
        .where((page) => !newPages.contains(page))
        .toList();


    unawaited(saveDoc(docID, removePages));         //pages leaving the loaded window
    ref.read(pageTilesProvider.notifier).remove(removePages.map((p) => p.pageID));


    double newPlaceholderHeight = 0;
    for (int i = 0; i < currentPage - lazyLoadRange; i++) {
      if (i >= 0 && i < doc.pageHeights.length) {
        newPlaceholderHeight += doc.pageHeights[i] + 2 * distanceBetweenPages;
      }
    }
    // New object instead of mutating doc: doc may be referenced by older states / snapshots.
    documents[docIndex] = doc.copyWith(
      placeholderHeight: newPlaceholderHeight,
      currentPageIndex: currentPage,
      pages: newPages,
    );

    state = documents;

    unawaited(updateIsolatedPages(docID));          //load pages in the background
  }

  Future<void> updateIsolatedPages(int docID) async {


    List<DocumentModel> documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;         //document was closed
    DocumentModel doc = documents[docIndex];

    List<PageModel> loadedPages = [];
    List<int> pagesToLoad = [];    //for collecting pageIDs of pages that have to be loaded from memory


    List<PageModel> newPages = [];


    for(final page in doc.pages) {
      if(page.isTemp) {
        pagesToLoad.add(page.pageID);
      } else if (_tiles[page.pageID]?.isEmpty ?? true) {
        loadedPages.add(page);        //loaded, but not rendered yet
      }
    }


    loadedPages.addAll(await loadPages(docID, pagesToLoad));

    // The state may have changed while the pages were loading (undo/redo, pages added or removed,
    // window moved, document closed). Writing back the snapshot taken above would revert those
    // changes, so apply the loaded pages to the current state instead.
    final currentIndex = _docIndexOf(docID);
    if (currentIndex == -1) return;
    final current = state[currentIndex];
    final loadedByID = {for (final p in loadedPages) p.pageID: p};

    List<PageModel> isolatePages = [];
    for (final page in current.pages) {
      final loaded = loadedByID[page.pageID];
      // replace temp pages that were loaded; keep pages that changed meanwhile
      if (loaded != null && (page.isTemp || identical(page, loaded))) {
        newPages.add(loaded);
        isolatePages.add(loaded);
      } else {
        newPages.add(page);
      }
    }

    final newDocuments = [...state];
    newDocuments[currentIndex] = current.copyWith(pages: newPages);
    state = newDocuments;

    for(final page in isolatePages) {
      unawaited(isolatePageTiles(docID, page.pageID));
    }


  }

  final Rect isolateRect = const Rect.fromLTWH(0, 0, 20, 20);
  final isolateScale = 20.0;
  final List<bool> runningIsolates = [false, false, false, false, false];
  List<int> pageIDsBeingRendered = [];
  List<int> isolateQueue = [];


  Future<void> isolatePageTiles(int docID, int pageID) async {



    if(pageIDsBeingRendered.contains(pageID)) {         //if the page is already being calculated by an isolate
      return;
    }

    if(isolateQueue.contains(pageID)) isolateQueue.removeWhere((id) => id == pageID);   //if the page is already in queue, remove it. If there is still no free isolate it will be readded anyway

    final documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;         //document was closed
    final doc = documents[docIndex];

    if (!doc.pages.map((p) => p.pageID).toList().contains(pageID)) { //if the page is no longer there abort
      if(isolateQueue.isNotEmpty) {
        unawaited(isolatePageTiles(docID, isolateQueue.first));
      }
      return;
    }

    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
    final page = doc.pages[pageIndex];


    int threadNumber = -1;

    for(int i = 0; i<runningIsolates.length; i++){    //find a free isolate, if none is found the page will be added to a queue

      if(runningIsolates[i]) {
        continue;
      } else {
        threadNumber = i;
        break;
      }
    }

    if(threadNumber == -1) {
      isolateQueue.add(pageID); //no free isolates -> will be send to queue
      return;
    }

    final requestId = DateTime.now().microsecondsSinceEpoch;

    _requestIds[threadNumber] = requestId;

    runningIsolates[threadNumber] = true;
    pageIDsBeingRendered.add(pageID);


    _receivePorts[requestId] = ReceivePort();

    _isolates[requestId] = await Isolate.spawn(
      _isolateEntry,
      _receivePorts[requestId]!.sendPort,
    );
    _receivePorts[requestId]!.listen((message) {

      if (message is SendPort) {

        _sendPorts[requestId] = message;

        _sendPorts[requestId]?.send({
          "type": "start",
          "data": [page.pageHeight, page.pageWidth, page.strokes, page.backgroundStrokes, isolateRect, isolateScale, pageIndex, docID, requestId,],
        });
      } else {
        _handleIsolateMessage(docID, pageID, threadNumber, requestId, message);
      }
    });
  }

  Future<void> _handleIsolateMessage(int docID, int pageID, int threadNumber, int requestID, dynamic message) async {
    // The document is looked up by ID after every await; it may have been closed meanwhile.
    // In that case the page counts as "no longer there".
    int pageIndexInDoc() {
      final docIndex = _docIndexOf(docID);
      if (docIndex == -1) return -1;
      return state[docIndex].pages.indexWhere((p) => p.pageID == pageID);
    }


    _receivePorts[requestID]?.close();
    _isolates[requestID]?.kill(priority: Isolate.immediate);

    runningIsolates[threadNumber] = false;
    pageIDsBeingRendered.removeWhere((id) => id == pageID);


    if(isolateQueue.isNotEmpty) {
      unawaited(isolatePageTiles(docID, isolateQueue.first));
    }

    if (message is SendPort) {
      _sendPorts[requestID] = message;
      return;
    }
    else {


      try {
        if (message.aborted == true) {
          return;
        }


        final result = message;


        int pageIndex = pageIndexInDoc();

        if (pageIndex == -1) {    //if page no longer exists abort
          return;
        }



        for (int row = 0; row < result.tiles.length; row++) {
          for (int col = 0; col < result.tiles[0].length; col++) {
            await result.tiles[row][col].renderAfterIsolate(
              result.sameWidths[row][col],
              result.lefts[row][col],
              result.rights[row][col],
              result.tileStrokes[row][col],
              result.scale,
              result.backgroundSameWidths[row][col],
              result.backgroundTileStrokes[row][col],
              result.backgroundLefts[row][col],
              result.backgroundRights[row][col],
            );
          }
          pageIndex = pageIndexInDoc();
          if (pageIndex == -1) {    //check again if page no longer exists abort
            return;
          }
        }



        pageIndex = pageIndexInDoc();

        if (pageIndex == -1) {    //check again if page no longer exists abort
          return;
        }

        ref.read(pageTilesProvider.notifier).set(pageID, result.tiles);
      } finally {
      }
    }
  }




  final Map<int, Isolate?> _isolates = {};
  final Map<int, SendPort?> _sendPorts = {};
  final Map<int, ReceivePort?> _receivePorts = {};





  void setPageColor(int docID, int pageIndex, Color color) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];    //copy old list

    final oldDoc = newDocuments[docIndex];

    final newPages = [
      for (int i = 0; i < oldDoc.pages.length; i++)
        if (i == pageIndex)
          oldDoc.pages[i].copyWith(pageColor: color)
        else
          oldDoc.pages[i],
    ];

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;
  }



  void setAllPageColors(int docID, Color color) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    final newPages = oldDoc.pages
        .map((page) => page.copyWith(pageColor: color))
        .toList();
    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages, docBackgroundColor: color);

    state = newDocuments;
  }


  Future<void> setAllBackgroundStrokesExecute(int docID, List<double> horizontalSpaces, List<double> verticalSpaces, Color strokeColor, double strokeWidth) async {
    final docs = [...state];
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;
    final doc = docs[docIndex];
    for (int i = 0; i<doc.pages.length; i++){
      await setBackgroundStrokesExecute(docID, doc.pages[i].pageID, horizontalSpaces, verticalSpaces, strokeColor, strokeWidth);
      await Future.delayed(Duration(milliseconds: 1));
    }


  }


  Future<void> setBackgroundStrokesExecute(int docID, int pageID, List<double> horizontalSpaces, List<double> verticalSpaces, Color strokeColor, double strokeWidth) async {

    final docs = [...state];
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;
    final doc = docs[docIndex];
    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
    if (pageIndex == -1) return;
    final newPage = doc.pages[pageIndex].withBackgroundSpacing(horizontalSpaces, verticalSpaces, strokeColor, strokeWidth);

    _replacePage(docID, newPage);

    final tiles = _tiles[pageID];
    if (tiles != null) {
      await updateTileGrid(tiles.grid, newPage.strokes, [], [], newPage.backgroundStrokes);
      ref.read(pageTilesProvider.notifier).touch(pageID);
    }
  }


  Future<void> initializeAllPageTiles(int docID) async {
    List<DocumentModel> docs = [...state];
    int docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;

    DocumentModel doc = docs[docIndex];



    for (final page in doc.pages) {
      if (page.isTemp) continue;
      ref.read(pageTilesProvider.notifier).set(page.pageID, await renderPageTiles(page));
      await Future.delayed(Duration(milliseconds: 1));
    }

  }


  /// Updates the tiles of [pageID] after strokes were added or removed.
  /// Pages that have no tiles yet get them from the isolate renderer.
  Future<void> updatePage(int docID, int pageID, List<Stroke> strokes, List<int> erasedStrokeIDs) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final page = state[docIndex].pages.where((p) => p.pageID == pageID).firstOrNull;
    final tiles = _tiles[pageID];
    if (page == null || tiles == null || tiles.isEmpty) return;

    await updateTileGrid(tiles.grid, page.strokes, strokes, erasedStrokeIDs, []);
    ref.read(pageTilesProvider.notifier).touch(pageID);
  }

  /// Tile grids of the current renderer, per pageID.
  Map<int, PageTiles> get _tiles => ref.read(pageTilesProvider);

  /// Replaces the page with the same ID as [page] in document [docID] (if it is loaded).
  void _replacePage(int docID, PageModel page) {
    state = [
      for (final doc in state)
        if (doc.docID == docID)
          doc.copyWith(pages: [
            for (final p in doc.pages) p.pageID == page.pageID ? page : p,
          ])
        else
          doc
    ];
  }


  /// Pushes [commands] onto the undo history of [docID]. Commands after the current position
  /// (undone ones) are dropped; the oldest commands go when [DocumentModel.maxAmountCommands] is
  /// exceeded.
  void addCommands(int docID, List<Command> commands) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final doc = state[docIndex];

    var history = [...doc.commands.take(doc.commandIndex), ...commands];
    if (history.length > doc.maxAmountCommands) {
      history = history.sublist(history.length - doc.maxAmountCommands);
    }

    final newDocs = [...state];
    newDocs[docIndex] = doc.copyWith(commands: history, commandIndex: history.length);
    state = newDocs;
  }


  /// True while an undo or redo runs. Both read the command index, await the page changes and
  /// then write the index back, so a second call during that time would repeat the same command.
  bool _undoRedoRunning = false;

  Future<void> undo(int docID) async {
    if (_undoRedoRunning) return;
    _undoRedoRunning = true;
    try {
      await _undo(docID);
    } finally {
      _undoRedoRunning = false;
    }
  }

  Future<void> redo(int docID) async {
    if (_undoRedoRunning) return;
    _undoRedoRunning = true;
    try {
      await _redo(docID);
    } finally {
      _undoRedoRunning = false;
    }
  }

  Future<void> _undo(int docID) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final doc = state[docIndex];
    if (doc.commandIndex <= 0) return;

    final command = doc.commands[doc.commandIndex - 1];
    print("documents_notifier: undo: ${command.runtimeType} at ${doc.commandIndex - 1} (commands: ${doc.commands.length})");

    if (command is ModifyElementsCommand) {
      await modifyElementsExecute(docID, command.pageID, command.removedStrokes, command.removedImages,
          [for (final s in command.addedStrokes) s.strokeID], [for (final i in command.addedImages) i.imageID]);
    } else if (command is ModifyPagesCommand) {
      await modifyPagesExecute(docID, command.removePages, command.removePageIndexes,
          [for (final p in command.addPages) p.pageID]);
    }

    _setCommandIndex(docID, doc.commandIndex - 1);
  }

  Future<void> _redo(int docID) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final doc = state[docIndex];
    if (doc.commandIndex >= doc.commands.length) return;

    final command = doc.commands[doc.commandIndex];
    print("documents_notifier: redo: ${command.runtimeType} at ${doc.commandIndex} (commands: ${doc.commands.length})");

    if (command is ModifyElementsCommand) {
      await modifyElementsExecute(docID, command.pageID, command.addedStrokes, command.addedImages,
          [for (final s in command.removedStrokes) s.strokeID], [for (final i in command.removedImages) i.imageID]);
    } else if (command is ModifyPagesCommand) {
      await modifyPagesExecute(docID, command.addPages, command.addPageIndexes,
          [for (final p in command.removePages) p.pageID]);
    }

    _setCommandIndex(docID, doc.commandIndex + 1);
  }

  void _setCommandIndex(int docID, int commandIndex) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final newDocs = [...state];
    newDocs[docIndex] = newDocs[docIndex].copyWith(commandIndex: commandIndex);
    state = newDocs;
  }


  /// Open `.bnf` files, per docID. Added by [loadDoc], removed by [closeDoc].
  final Map<int, BnfRepository> _repositories = {};

  /// Per document: the last save in the chain. Saves run in call order, and each one writes the
  /// metadata that is current when it runs (not when it was requested).
  final Map<int, Future<void>> _saveChains = {};

  Future<void> saveAsBnf(int docID) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    await saveDoc(docID, state[docIndex].pages);
  }

  /// Reads the pages with [pageIDs] from the file of document [docID].
  /// Pages missing from the file are left out; returns [] if the document is closed.
  Future<List<PageModel>> loadPages(int docID, List<int> pageIDs) async {
    if (pageIDs.isEmpty) return [];
    final repository = _repositories[docID];
    if (repository == null) return [];
    try {
      final records = await repository.readPages(pageIDs);
      return await decodePages(repository, [
        for (final id in pageIDs)
          if (records[id] != null) records[id]!,
      ]);
    } on StateError {
      print('documents_notifier: loadPages: document $docID was closed while loading');
      return [];
    }
  }

  /// Loads the document at [pathToFile] into the editor slot and returns its new docID,
  /// or null if the file does not exist. Throws a [BnfFormatException] for invalid files.
  ///
  /// Only the first pages are read here; the rest is loaded on demand with [loadPages].
  Future<int?> loadDoc(String pathToFile) async {
    if (!await File(pathToFile).exists()) return null;

    print('documents_notifier: loadDoc: $pathToFile');

    final repository = await BnfRepository.open(pathToFile);
    final metadata = repository.metadata;

    final defaultPageJson = metadata['defaultPage'] as Map<String, dynamic>?;
    final defaultPage = defaultPageJson != null
        ? await PageModel.fromJson(defaultPageJson)
        : PageModel(pageWidth: 297, pageHeight: 210, pageColor: Colors.white70);

    final created = metadata['created'] != null ? DateTime.parse(metadata['created'] as String) : DateTime.now();

    var pageHeights = ((metadata['pageHeights'] as List?) ?? [0.0]).map((e) => (e as num).toDouble()).toList();
    var pageList = ((metadata['pageList'] as List?) ?? []).map((e) => (e as num).toInt()).toList();

    // Drop pages that are listed but not stored (e.g. added, then the app died before saving).
    final missing = pageList.where((id) => !repository.hasPage(id)).toSet();
    if (missing.isNotEmpty) {
      print('documents_notifier: loadDoc: missing pages $missing');
      if (pageHeights.length == pageList.length) {
        pageHeights = [
          for (var i = 0; i < pageList.length; i++)
            if (!missing.contains(pageList[i])) pageHeights[i],
        ];
      }
      pageList = pageList.where((id) => !missing.contains(id)).toList();
    }

    print('documents_notifier: loadDoc: pageList=$pageList');

    final doc = DocumentModel(
      pathToFile: pathToFile,
      pages: const [],
      docBackgroundColor: Colors.purpleAccent,
      defaultPage: defaultPage,
      author: metadata['author'] as String? ?? '?',
      title: metadata['title'] as String? ?? '?',
      created: created,
      pageHeights: pageHeights,
      pageList: pageList,
    );

    // The editor slot holds one document for now (P4-03): close whatever file was there.
    final docIndex = currentDocIndex;
    final previous = _repositories.remove(state[docIndex].docID);
    if (previous != null) unawaited(previous.close());
    _repositories[doc.docID] = repository;

    final pages = await loadPages(doc.docID, pageList.take(lazyLoadRange + 1).toList());
    print('documents_notifier: loadDoc: loaded pages=${pages.length}');

    final newDocuments = [...state];
    newDocuments[docIndex] = doc.copyWith(pages: List.unmodifiable(pages), currentPageIndex: 0);
    state = newDocuments;

    return doc.docID;
  }

  /// Saves [pagesToSave] (unchanged ones are skipped) and the document metadata.
  /// Compacts the file when enough garbage has piled up.
  Future<void> saveDoc(int docID, List<PageModel> pagesToSave) {
    final previous = _saveChains[docID] ?? Future<void>.value();
    final save = previous.then((_) => _saveDocInternal(docID, pagesToSave));
    _saveChains[docID] = save.then((_) {}, onError: (_) {});
    return save;
  }

  Future<void> _saveDocInternal(int docID, List<PageModel> pagesToSave) async {
    final repository = _repositories[docID];
    if (repository == null || _docIndexOf(docID) == -1) {
      print("documents_notifier: _saveDocInternal: document $docID is no longer open, ${pagesToSave.length} page(s) not saved");
      return;
    }

    final encoded = await encodePages(pagesToSave);

    final docIndex = _docIndexOf(docID);        //state may have changed while encoding
    if (docIndex == -1) return;
    final written = await repository.write(
      pages: encoded.pages,
      images: encoded.images,
      metadata: state[docIndex].toMetadata(),
    );

    if (written && repository.shouldCompact) {
      print('documents_notifier: compacting ${repository.path} (${repository.garbageBytes} of ${repository.fileLength} bytes garbage)');
      await repository.compact();         //keeps deleted pages: the undo history may need them
    }
  }

  /// Saves the loaded pages, compacts the file if that frees enough space, closes the file and
  /// clears the document. Pages no longer in the document are dropped from the file here,
  /// since the undo history that could bring them back ends with the document.
  Future<void> closeDoc(int docID) async {
    await saveAsBnf(docID);
    await (_saveChains.remove(docID) ?? Future<void>.value());

    final repository = _repositories.remove(docID);
    final docIndex = _docIndexOf(docID);
    if (repository != null) {
      try {
        if (docIndex != -1) {
          final keep = state[docIndex].pageList.toSet();
          final reclaimable = await repository.reclaimableBytes(keep);
          if (reclaimable > 0 && reclaimable >= repository.fileLength * closeCompactRatio) {
            await repository.compact(keepPages: keep);
          }
        }
      } finally {
        await repository.close();
      }
    }

    clearDoc(docID);
  }

  /// [closeDoc] compacts when at least this share of the file can be freed.
  static const double closeCompactRatio = 0.1;

}


void _isolateEntry(SendPort sendPort) async {
  bool cancelled = false;


  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {


    if (msg['type'] == 'cancel') {
      cancelled = true;
    }
    else if (msg['type'] == 'start') {


      cancelled = false;

      final List args = msg['data'];


      final double pageHeight = args[0];
      final double pageWidth = args[1];
      final strokes = args[2];
      final backgroundStrokes = args[3];
      final Rect rect = args[4];
      final double scale = args[5];
      final int pageIndex = args[6];
      final docID = args[7];


      final tiles = <List<Tile>>[];
      final tileStrokes = [];
      final sameWidths = [];
      final rights = [];
      final lefts = [];
      final backgroundTileStrokes = [];
      final backgroundSameWidths = [];
      final backgroundRights = [];
      final backgroundLefts = [];

      final rows = (pageHeight / rect.height).ceil();
      final cols = (pageWidth / rect.width).ceil();

      for (int row = 0; row < rows; row++) {

        final rowTiles = <Tile>[];
        final rowTileStrokes = [];
        final rowSameWidths = [];
        final rowRights = [];
        final rowLefts = [];
        final rowBgTiles = [];
        final rowBgSameWidths = [];
        final rowBgRights = [];
        final rowBgLefts = [];

        for (int col = 0; col < cols; col++) {
          if (cancelled) {
            sendPort.send((aborted: true));
            cancelled = false;
            return;
          }

          final tile = Tile(
            Rect.fromLTWH(
              col * rect.width,
              row * rect.height,
              rect.width,
              rect.height,
            ),
          );

          final tileResult = iso.preCalculateSingleTile(
            tile,
            strokes,
            backgroundStrokes,
            scale,
          );

          rowTiles.add(tileResult.tile);
          rowTileStrokes.add(tileResult.tileStrokes);
          rowLefts.add(tileResult.lefts);
          rowRights.add(tileResult.rights);
          rowSameWidths.add(tileResult.sameWidths);

          rowBgTiles.add(tileResult.backgroundTileStrokes);
          rowBgLefts.add(tileResult.backgroundLefts);
          rowBgRights.add(tileResult.backgroundRights);
          rowBgSameWidths.add(tileResult.backgroundSameWidths);

          await Future.delayed(Duration.zero);
          await Future.delayed(const Duration(milliseconds: 0));
        }

        tiles.add(rowTiles);
        tileStrokes.add(rowTileStrokes);
        sameWidths.add(rowSameWidths);
        rights.add(rowRights);
        lefts.add(rowLefts);

        backgroundTileStrokes.add(rowBgTiles);
        backgroundSameWidths.add(rowBgSameWidths);
        backgroundRights.add(rowBgRights);
        backgroundLefts.add(rowBgLefts);
      }


      sendPort.send((aborted: false, tiles: tiles, tileStrokes: tileStrokes, sameWidths: sameWidths, rights: rights, lefts: lefts, backgroundTileStrokes: backgroundTileStrokes, backgroundSameWidths: backgroundSameWidths, backgroundRights: backgroundRights, backgroundLefts: backgroundLefts, scale: scale, pageIndex: pageIndex, docID : docID));

    }
  });
}