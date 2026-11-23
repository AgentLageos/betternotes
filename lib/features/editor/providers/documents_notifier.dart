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
import '../models/commands/empty_command.dart';

import '../models/page/image_model.dart';

import '../models/page/tile.dart';


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

  void setPageHeight(int docID, int pageIndex, double value) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;


    final newDocuments = [...state];    //copy old list

    final oldDoc = newDocuments[docIndex];

    final newPages = [
      for (int i = 0; i < oldDoc.pages.length; i++)
        if (i == pageIndex)
          oldDoc.pages[i].copyWith(pageHeight: value)
        else
          oldDoc.pages[i],
    ];

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;

  }

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


  Future<void> addPageExecute(int docID, double pageHeight, double pageWidth, List<Stroke>? strokes, List<Stroke>? backgroundStrokes, List<ImageModel>? images, Color pageColor, bool? backgroundUpdate) async {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final newDocuments = [...state];

    final oldDoc = newDocuments[docIndex];

    final newPage = PageModel(
      strokes: strokes ?? [],
      backgroundStrokes: backgroundStrokes ?? [],
      images: images ?? [],
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      pageColor: pageColor,
      tiles: [[]],
    );

    await newPage.initializeTiles();

    final newPages = [...oldDoc.pages, newPage];

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;
  }

  void addPagesWithID(int docID, List<PageModel> newPages, List<int> positions) {
    final docIndex = _docIndexOf(docID);
    if (docIndex == -1) return;
    final newDocuments = [...state];

    final oldDoc = newDocuments[docIndex];

    List<PageModel> pages = oldDoc.pages;


    if (positions[0] == -1){                                      //when position is unknown, create the new page at end of list
      pages = [...oldDoc.pages, ...newPages];
    }
    else {
      for (int i = 0; i<newPages.length; i++){                    //if position is known, create new page there (if this position is end, create at end)
        if (positions[i]<pages.length){
          pages.insert(positions[i], newPages[i]);
        }
        else {
          pages.add(newPages[i]);
        }
      }
    }


    newDocuments[docIndex] = oldDoc.copyWith(pages: pages);

    state = newDocuments;
  }

  Future<void> setPage(int docID, int pageID, PageModel newDefaultPage) async {
    List<DocumentModel> docs = [...state];
    DocumentModel doc = docs.firstWhere((d) => d.docID == docID);
    PageModel page = doc.pages.firstWhere((p) => p.pageID == pageID);
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);


    final newPage = page.copyWith(pageColor: newDefaultPage.pageColor, pageHeight: newDefaultPage.pageHeight, pageWidth: newDefaultPage.pageWidth, backgroundStrokes: newDefaultPage.backgroundStrokes, tiles: newDefaultPage.tiles);


    final newPages = [
      for (int i = 0; i < doc.pages.length; i++)
        if (i == pageIndex)
          newPage
        else
          doc.pages[i],
    ];

    doc = doc.copyWith(pages: newPages);

    docs[docIndex] = doc;

    state = docs;


  }

  Future<void> setAllPages(int docID, PageModel newDefaultPage) async {
    List<DocumentModel> docs = [...state];
    DocumentModel doc = docs.firstWhere((d) => d.docID == docID);
    final docIndex = docs.indexWhere((d) => d.docID == docID);

    final newPages = doc.pages.map((page) => page.copyWith(pageWidth: newDefaultPage.pageWidth, pageHeight: newDefaultPage.pageHeight, pageColor: newDefaultPage.pageColor, backgroundStrokes: newDefaultPage.backgroundStrokes,)).toList();

    docs[docIndex] = doc.copyWith(pages: newPages);

    state = docs;

    await initializeAllPageTiles(docID);

  }

  void setDefaultPage(int docID, PageModel newDefaultPage) {
    List<DocumentModel> docs = [...state];
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;
    docs[docIndex] = docs[docIndex].copyWith(defaultPage: newDefaultPage);
    state = docs;

  }

  Future<void> modifyElements(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<ImageModel> removeImages) async {



    final docs = [...state];
    final doc = docs.firstWhere((d) => d.docID == docID);
    final page = doc.pages.firstWhere((p) => p.pageID == pageID);


    final removeStrokes = page.strokes.where((s) => removeStrokeIDs.contains(s.strokeID)).toList();
    final List<int>removeImageIDs = removeImages.map((s) => s.imageID).toList();

    addCommands(docID, [ModifyElementsCommand(addedStrokes: addStrokes, addedImages: addImages, removedStrokes: removeStrokes, removedImages: removeImages, pageID: pageID)]);
    await modifyElementsExecute(docID, pageID, addStrokes, addImages, removeStrokeIDs, removeImageIDs);

  }

  Future<void> modifyElementsExecute(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<int> removeImageIDs) async {

    state = [
      for (int i = 0; i < state.length; i++)
        if (state[i].docID == docID)
          state[i].copyWith(
            pages: [
              for (int j = 0; j < state[i].pages.length; j++)
                if (state[i].pages[j].pageID == pageID)
                  state[i].pages[j].copyWith(
                    images: [...state[i].pages[j].images.where((img) => !removeImageIDs.contains(img.imageID)), ...addImages],
                    strokes: [...state[i].pages[j].strokes.where((stroke) => !removeStrokeIDs.contains(stroke.strokeID)), ...addStrokes]
                  )
                else
                  state[i].pages[j]
            ],
          )
        else
          state[i]
    ];

    await updatePage(docID, pageID, addStrokes, removeStrokeIDs);

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
      final page = doc.pages.where((p) => p.pageID == id).firstOrNull;
      final position = doc.pageList.indexOf(id);
      if (page == null || position == -1) continue;
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
      } else if (page.tiles.isEmpty || page.tiles.first.isEmpty) {
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

        final doc = state[_docIndexOf(docID)];


        doc.pages[pageIndex].tiles = result.tiles;


        state = [
          for (int i = 0; i < state.length; i++)
            if (state[i].docID == result.docID)
              state[i].copyWith(pages: doc.pages)
            else
              state[i]
        ];
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


  void setNewImage (int docID, int pageID, bool value) {
    List<DocumentModel> docs = [...state];
    DocumentModel doc = docs.firstWhere((d) => d.docID == docID);
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    docs[docIndex] = doc.copyWith(pages: doc.pages);
    state = docs;

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
    final newPages = [...doc.pages];


    newPages[pageIndex].setBackgroundStrokesBySpacing(horizontalSpaces, verticalSpaces, strokeColor, strokeWidth);

    await newPages[pageIndex].updateTiles([], [], newPages[pageIndex].backgroundStrokes);


    state = [
      for (int i = 0; i < state.length; i++)
        if (state[i].docID == docID)
          state[i].copyWith(pages: newPages)
        else
          state[i]
    ];
  }


  Future<void> initializeAllPageTiles(int docID) async {
    List<DocumentModel> docs = [...state];
    int docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;

    DocumentModel doc = docs[docIndex];



    for (int i=0; i<doc.pages.length; i++) {
      await doc.pages[i].initializeTiles();
      await Future.delayed(Duration(milliseconds: 1));
    }

  }


  Future<void> updatePage(int docID, int pageID, List<Stroke> strokes, List<int> erasedStrokeIDs) async {
    final docs = [...state];

    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) return;

    final doc = docs[docIndex];

    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
    if (pageIndex == -1) return;

    // ⚠️ IMPORTANT: replace only this one page
    final newPages = [...doc.pages];


    await newPages[pageIndex].updateTiles(strokes, erasedStrokeIDs, []);


    newPages[pageIndex].erasedIDs = [];

    docs[docIndex] = doc.copyWith(pages: newPages);

    state = docs;


  }


  void addCommands(int docID, List<Command> commands) {
    final newDocs = [...state];
    final docIndex = newDocs.indexWhere((d) => d.docID == docID);
    final doc = newDocs[docIndex];
    List<Command> newCommands = doc.commands;

    for (int i = 0; i<commands.length; i++) {
      if (doc.commandIndex<doc.commands.length) {                                              //when not at top of the stack remove all commands after the current index:     [][][][][i][+]  |  [x][x][x][x]
        doc.commands.removeRange(doc.commandIndex, doc.commands.length);
      }

      if (doc.commands.length >= doc.maxAmountCommands) {                                           //remove oldest entry when max amount of undo steps is reached:     <--[] | [0][1][2][3][4]..[+]<--
        doc.commands.removeAt(0);  // remove oldest command
      }
      newCommands.add(commands[i]);
      doc.commandIndex=doc.commands.length;

    }

    newDocs[docIndex] = doc.copyWith(commands: newCommands, commandIndex: doc.commandIndex);

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

    final docs = [...state];


    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) {
      return;
    }

    DocumentModel doc = docs[docIndex];

    List<Command> commands = doc.commands;


    Command command;

    int commandIndex = doc.commandIndex;



    for(final page in doc.pages){                               //current selections will be canceled when undo/redo is called
      setNewImage(doc.docID, page.pageID, false);
    }

    if (doc.commandIndex>0) {
      commandIndex = doc.commandIndex-1;
      command = commands[commandIndex];
    }
    else {
      command=EmptyCommand();
    }

    print("documents_notifier: undo: ${command.runtimeType} at ${doc.commandIndex - 1} (commands: ${commands.length})");


    if(command is ModifyElementsCommand) {



      final modifyElementsCommand = command;
      final pageIndex = doc.pages.indexWhere((p) => p.pageID == modifyElementsCommand.pageID);
      if (pageIndex == -1) {
        print("documents_notifier: undo: page not loaded");
        return;
      }


      final addedStrokeIDs = modifyElementsCommand.addedStrokes.map((s) => s.strokeID).toList();
      final addedImageIDs = modifyElementsCommand.addedImages.map((m) => m.imageID).toList();

      await modifyElementsExecute(docID, modifyElementsCommand.pageID, modifyElementsCommand.removedStrokes, modifyElementsCommand.removedImages, addedStrokeIDs, addedImageIDs);

    }
    else if(command is ModifyPagesCommand) {
      final modifyPagesCommand = command;
      final addPageIDs = modifyPagesCommand.addPages.map((p) => p.pageID).toList();
      await modifyPagesExecute(docID, modifyPagesCommand.removePages, modifyPagesCommand.removePageIndexes, addPageIDs);

    }

    final newDocs = [...state];

    newDocs[docIndex] = newDocs[docIndex].copyWith(commands: commands, commandIndex: commandIndex);

    state = newDocs;

  }


  Future<void> _redo(int docID) async {
    final docs = [...state];
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    DocumentModel doc = docs[docIndex];
    List<Command> commands = doc.commands;

    Command command;

    int commandIndex = doc.commandIndex;


    if (doc.commandIndex<doc.commands.length) {
      command = commands[commandIndex];
      commandIndex = doc.commandIndex+1;

    }
    else {
      command=EmptyCommand();
    }

    print("documents_notifier: redo: ${command.runtimeType} at ${doc.commandIndex} (commands: ${commands.length})");




    if(command is ModifyElementsCommand) {

      final modifyElementsCommand = command;

      final pageIndex = doc.pages.indexWhere((p) => p.pageID == modifyElementsCommand.pageID);
      if (pageIndex == -1) {
        print("documents_notifier: redo: page not loaded");
        return;
      }

      final removedStrokeIDs = modifyElementsCommand.removedStrokes.map((s) => s.strokeID).toList();
      final removedImageIDs = modifyElementsCommand.removedImages.map((m) => m.imageID).toList();

      await modifyElementsExecute(docID, modifyElementsCommand.pageID, modifyElementsCommand.addedStrokes, modifyElementsCommand.addedImages, removedStrokeIDs, removedImageIDs);
    }
    else if(command is ModifyPagesCommand) {
      final modifyPagesCommand = command;
      final removePageIDs = modifyPagesCommand.removePages.map((p) => p.pageID).toList();
      await modifyPagesExecute(docID, modifyPagesCommand.addPages, modifyPagesCommand.addPageIndexes, removePageIDs);
    }

    final newDocs = [...state];





    newDocs[docIndex] = newDocs[docIndex].copyWith(commands: commands, commandIndex: commandIndex);

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
        : PageModel(strokes: [], backgroundStrokes: [], images: [], pageWidth: 297, pageHeight: 210, pageColor: Colors.white70, tiles: [[]]);

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