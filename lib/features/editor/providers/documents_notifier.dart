import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:typed_data';

import 'package:betternotes/features/editor/models/commands/modify_elements_command.dart';
import 'package:betternotes/features/editor/models/commands/modify_pages_command.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';

import '../../../core/utils/isolates/initializeTiles.dart' as iso;
import '../../../core/utils/id_generator.dart';
import '../models/commands/command.dart';
import '../models/commands/empty_command.dart';

import '../models/page/image_model.dart';

import '../models/page/tile2.dart';


class DocumentsNotifier extends Notifier<List<DocumentModel>> {

  int currentDocIndex = 0;

  Isolate? runningIsolate;



  List<int> requestID = [0,0,0,0,0];

  final Map<int, int> _requestIds = {};



  @override
  List<DocumentModel> build() => [DocumentModel(pages: [], created: DateTime.now(), author: '', title: '', )];

  void setPageHeight(int docIndex, int pageIndex, double value) {

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

    //setBackgroundStrokesExecute(docID, pageID, horizontalSpace, verticalSpace, strokeColor, strokeWidth)
  }

  Future<void> setAllHeights(int docIndex, double value) async {

    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    final newPages = oldDoc.pages
        .map((page) => page.copyWith(pageHeight: value))
        .toList();

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;

    await initializeAllPageTiles(oldDoc.docID);
  }

  void setPageWidth(int docIndex, int pageIndex, double value) {

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

  Future<void> setAllWidths(int docIndex, double value) async {

    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    final newPages = oldDoc.pages
        .map((page) => page.copyWith(pageWidth: value))
        .toList();

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;

    await initializeAllPageTiles(oldDoc.docID);
  }


  Future<void> addPageExecute(int docIndex, double pageHeight, double pageWidth, List<Stroke>? strokes, List<Stroke>? backgroundStrokes, List<ImageModel>? images, Color pageColor, bool? backgroundUpdate) async {
    final newDocuments = [...state];

    final oldDoc = newDocuments[docIndex];

    final newPage = PageModel(
      strokes: strokes ?? [],
      backgroundStrokes: backgroundStrokes ?? [],
      images: images ?? [],
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      pageColor: pageColor,
      //backgroundUpdate: backgroundUpdate ?? false,
      tiles: [[]],
    );

    await newPage.initializeTiles();

    final newPages = [...oldDoc.pages, newPage];

    newDocuments[docIndex] = oldDoc.copyWith(pages: newPages);

    state = newDocuments;
  }

  void addPagesWithID(int docIndex, List<PageModel> newPages, List<int> positions) {
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


    //final List<PageModel>

    newDocuments[docIndex] = oldDoc.copyWith(pages: pages);

    state = newDocuments;
  }

  Future<void> setPage(int docID, int pageID, PageModel newDefaultPage) async {
    List<DocumentModel> docs = [...state];
    DocumentModel doc = docs.firstWhere((d) => d.docID == docID);
    PageModel page = doc.pages.firstWhere((p) => p.pageID == pageID);
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);

    List<PageModel> pages = doc.pages;

    final newPage = page.copyWith(pageColor: newDefaultPage.pageColor, pageHeight: newDefaultPage.pageHeight, pageWidth: newDefaultPage.pageWidth, backgroundStrokes: newDefaultPage.backgroundStrokes, tiles: newDefaultPage.tiles);


    //pages[pageIndex] = newPage;

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

    //await initializeAllPageTiles(docID);


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
    //DocumentModel doc = docs.firstWhere((d) => d.docID == docID);
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    docs[docIndex] = docs[docIndex].copyWith(defaultPage: newDefaultPage);


  }

  Future<void> modifyElements(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<ImageModel> removeImages) async {



    final docs = [...state];
    final doc = docs.firstWhere((d) => d.docID == docID);
    final page = doc.pages.firstWhere((p) => p.pageID == pageID);


    final removeStrokes = page.strokes.where((s) => removeStrokeIDs.contains(s.strokeID)).toList();
    //final removeImages = page.images.where((s) => removeImageIDs.contains(s.imageID)).toList();
    final List<int>removeImageIDs = removeImages.map((s) => s.imageID).toList();

    addCommands(docID, [ModifyElementsCommand(addedStrokes: addStrokes, addedImages: addImages, removedStrokes: removeStrokes, removedImages: removeImages, pageID: pageID)]);
    await modifyElementsExecute(docID, pageID, addStrokes, addImages, removeStrokeIDs, removeImageIDs);

  }

  Future<void> modifyElementsExecute(int docID, int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<int> removeImageIDs) async {

    //print(state[0].pages.first.strokes.last.points.first.pos);
    state = [
      for (int i = 0; i < state.length; i++)
        if (state[i].docID == docID)
          state[i].copyWith(
            pages: [
              for (int j = 0; j < state[i].pages.length; j++)
                if (state[i].pages[j].pageID == pageID)
                //List<ImageModel> images = state[i].pages[j].images;
                  state[i].pages[j].copyWith(
                    images: [...state[i].pages[j].images.where((img) => !removeImageIDs.contains(img.imageID)).toList(), ...addImages],
                    strokes: [...state[i].pages[j].strokes.where((stroke) => !removeStrokeIDs.contains(stroke.strokeID)).toList(), ...addStrokes]
                  )
                else
                  state[i].pages[j]
            ],
          )
        else
          state[i]
    ];

    //if (removeStrokeIDs.isNotEmpty || addStrokes.isNotEmpty)
    await updatePage(docID, pageID, addStrokes, removeStrokeIDs);

      //print(state[0].pages.first.strokes.last.points.first.pos);
  }

  Future<void> modifyPages(int docID, List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async{

    final doc = [...state].firstWhere((d) => d.docID == docID);

    List<PageModel> pages = doc.pages;
    List<int> removePageIndexes = [];

    for (int i = 0; i<removePageIDs.length; i++){               //remembering the position where the page was in the list
      for (int j = 0; j<pages.length;j++){
        if (pages[j].pageID==removePageIDs[i]){
          removePageIndexes.add(j);
        }
      }
    }

    final removePages = doc.pages.where((page) => removePageIDs.contains(page.pageID)).toList();

    addCommands(docID, [ModifyPagesCommand(addPages: addPages, addPageIndexes: addPageIndexes,removePages: removePages, removePageIndexes: removePageIndexes)]);
    await modifyPagesExecute(docID, addPages, addPageIndexes, removePageIDs);


  }

  Future<void> modifyPagesExecute(int docID, List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async {

    final doc = [...state].firstWhere((d) => d.docID == docID);

    List<PageModel> pages = [];
    pages.addAll(doc.pages);
    final List<Future<void>> futures = [];
    for (var p in addPages) {
      futures.add(() async {
        if (pages.any((e) => e.pageID == p.pageID)) p.copyWith(pageID: IdGenerator.next());         //this needs to be here otherwise red screen of death will appear because of duplicate keys (for some reason?)
        //await p.initializeTiles();
      }());
    }
    await Future.wait(futures);

    print("documents_notifier: modifyPagesExecute: ${doc.pageList}");

    for (int i = 0; i<addPageIndexes.length; i++) {
      if(addPageIndexes[i] > doc.pages.length) {
        pages.add(addPages[i]);
        doc.pageHeights.add(addPages[i].pageHeight);
        doc.pageList.add(addPages[i].pageID);
      }
      else {
        pages.insert(addPageIndexes[i], addPages[i]);
        doc.pageHeights.insert(addPageIndexes[i], addPages[i].pageHeight);
        doc.pageList.insert(addPageIndexes[i], addPages[i].pageID);
      }
    }

    print("documents_notifier: modifyPagesExecute: ${doc.pageList}");



    final indices = removePageIDs.map((id) => doc.pageList.indexWhere((pageID) => pageID == id)).toList();
    //print(indices);

    for (final index in indices) {
      doc.pageHeights.removeAt(index);
    }
    pages = pages.where((page) => !removePageIDs.contains(page.pageID)).toList();
    doc.pageList = doc.pageList.where((id) => !removePageIDs.contains(id)).toList();



    state = [
      for (int i = 0; i < state.length; i++)
        if (state[i].docID == docID)
          state[i].copyWith(
            pages: pages,
            pageList: doc.pageList,
            pageHeights: doc.pageHeights
          )
        else state[i]
    ];

    //print("documents_notifier: modifyPagesExecute: pageList: ${[...state].firstWhere((d) => d.docID == docID).pageList}");
    setCurrentPageIndex3(docID, doc.currentPageIndex);

  }


  void clearDoc(int docIndex) {
    if (docIndex < 0 || docIndex >= state.length) return;

    final newDocuments = [...state];
    final oldDoc = newDocuments[docIndex];

    newDocuments[docIndex] = oldDoc.copyWith(pages: []);

    state = newDocuments;


  }

  final lazyLoadRange = 1;
  final distanceBetweenPages = 12;

  Future<void> setCurrentPageIndex3(int docID, int currentPage) async {

    //print("documents_notifier: currentPage: ${currentPage}");
    List<DocumentModel> documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    DocumentModel doc = documents[docIndex];


    int lowerIndex = currentPage - lazyLoadRange;
    if (lowerIndex < 0) lowerIndex = 0;
    int upperIndex = currentPage + lazyLoadRange;
    if (upperIndex > doc.pageHeights.length-1) upperIndex = doc.pageHeights.length-1;


    int j = 0;

    List<int> oldPageIDs = doc.pages.map((page) => page.pageID).toList();
    List<int> newPageIDs = [];

    List<PageModel> newPages = [];

    //print("documents_notifier: setcurrentPage: pages: ${doc.pageList}");
    for (int i = currentPage-lazyLoadRange; i<currentPage+lazyLoadRange+1; i++){      //adding new pages
      if(i>=0 && i<doc.pageList.length) {
        //print(i);
        newPageIDs.add(doc.pageList[i]);
        if(!oldPageIDs.contains(doc.pageList[i])) {
          newPages.add(PageModel(isTemp: true, pageID: doc.pageList[i]));
        } else newPages.add(doc.pages.firstWhere((p) => p.pageID == doc.pageList[i]));
      }
      j++;
    }

    List<PageModel> removePages = doc.pages
        .where((page) => !newPages.contains(page))
        .toList();

    //print("documents_notifier: setcurrentPage: pages: ${doc.pageList}");
    //print("documents_notifier: removepages: $removePages");

    saveDoc2(docID, removePages);

    //print("documents_notifier: setCurrentPage3: pageList: ${doc.pageList}");
    //print("documents_notifier: setCurrentPage3: ${newPages.length}");

    double newPlaceholderHeight = 0;
    for (int i = 0; i < currentPage - lazyLoadRange; i++) {
      if (i >= 0 && i < doc.pageHeights.length) {
        newPlaceholderHeight += doc.pageHeights[i] + 2 * distanceBetweenPages;
      }
    }
    doc.placeholderHeight = newPlaceholderHeight;

    //print("documents_notifier: setCurrentPageIndex: ${doc.placeholderHeight}");

    doc.currentPageIndex = currentPage;
    //print("documents_notifier: currentPage befor write: $currentPage");
    doc.pages = newPages;

    state = documents;

    //print("documents_notifier: setCurrentPage: newPageIDs: $newPageIDs");
    //print("documents_notifier: setcurrentPage: pages: ${doc.pages.map((p) => p.pageID).toList()}");
    //print("documents_notifier: setCurrentPage: currentPage: ${doc.currentPageIndex}");
    updateIsolatedPages(docID);
    //print("documents_notifier: setcurrentPage: pages: ${doc.pages.length}");
  }

  Future<void> updateIsolatedPages(int docID) async {


    //print("documents_notifier: loadAndMapPages");
    List<DocumentModel> documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    DocumentModel doc = documents[docIndex];

    List<PageModel> loadedPages = [];
    List<int> pagesToLoad = [];    //for collecting pageIDs of pages that have to be loaded from memory


    //print(pageIDs.first);
    List<PageModel> newPages = [];


    for(final page in doc.pages) {
      if(page.isTemp) pagesToLoad.add(page.pageID);
      else if (page.tiles.isEmpty) loadedPages.add(page);
      else if (page.tiles.isNotEmpty) if(page.tiles.first.isEmpty) loadedPages.add(page);
    }

    //loadedPages = await loadPages(doc.pathToFile, pagesToLoad, false);

    //print("documents_notifier: updateIsolatedPages: doc.pages: ${doc.pages.map((p) => p.pageID).toList()}");
    loadedPages.addAll(await loadPages2(doc.pathToFile, pagesToLoad, false));
    //print("documents_notififer: updateIsolatedPages: backgroundStrokes: ${loadedPages.first.backgroundStrokes.length}");

    //print("documents_notifier: updateIsolatedPages: loadedPages: $loadedPages");
    //print(pagesToLoad);
    //print(doc.pages.map((p) => p.pageID).toList());





    List<PageModel> isolatePages = [];
    //print("documents_notifier: updateIsoltedPages: pagesToLoad.length: ${pagesToLoad.length}");
    for(int i = 0; i < doc.pages.length; i++) {
      if(loadedPages.map((p) => p.pageID).toList().contains(doc.pages[i].pageID)) {
        newPages.add(loadedPages.firstWhere((p) => p.pageID == doc.pages[i].pageID)); //check if the id of the page that has just been loaded is (still) in the loaded pages, then overwrite temp page
        //print("documents_notififer: updateIsolatedPages: backgroundStrokes: ${.backgroundStrokes.length}");

        isolatePages.add(loadedPages.firstWhere((p) => p.pageID == doc.pages[i].pageID));
      }
      else newPages.add(doc.pages[i]);
    }

    doc.pages =  newPages;
    state = documents;
    //print("documents_notifier: updateIsolatedPages: doc.pages: ${doc.pages.map((p) => p.pageID).toList()}");

    for(final page in isolatePages) {
      isolatePageTiles5(docID, page.pageID);
    }

    //print("documents_notifier: runningIsolates: $runningIsolates   pageIDsBeingRendered: $pageIDsBeingRendered    isolateQueue: $isolateQueue");

  }

  final Rect isolateRect = const Rect.fromLTWH(0, 0, 20, 20);
  final isolateScale = 20.0;
  //final Map<int, bool> runningIsolates = {0: false, 1: false, 2: false, 3: false, 4: false};
  final List<bool> runningIsolates = [false, false, false, false, false];
  List<int> pageIDsBeingRendered = [];
  List<int> isolateQueue = [];


  Future<void> isolatePageTiles5(int docID, int pageID) async {



    if(pageIDsBeingRendered.contains(pageID)) {         //if the page is already being calculated by an isolate
      //print("documents_notifier: isolatePageTiles5: page is already being rendered");
      return;
    }

    if(isolateQueue.contains(pageID)) isolateQueue.removeWhere((id) => id == pageID);   //if the page is already in queue, remove it. If there is still no free isolate it will be readded anyway

    final documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    final doc = documents[docIndex];

    if (!doc.pages.map((p) => p.pageID).toList().contains(pageID)) { //if the page is no longer there abort
      if(isolateQueue.isNotEmpty) {
        //print("documents_notifier: handleMessage: still items in queue...");
        isolatePageTiles5(docID, isolateQueue.first);
      }
      return;
    }

    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
    final page = doc.pages[pageIndex];

    //print("documents_notifier: isolatePageTiles5: page.backgroundStrokes: ${page.backgroundStrokes.length}");


    int threadNumber = -1;

    //print("runningIsolates: $runningIsolates");
    for(int i = 0; i<runningIsolates.length; i++){    //find a free isolate, if none is found the page will be added to a queue

      if(runningIsolates[i]) continue;
      else {
        threadNumber = i;
        break;
      }
      print(runningIsolates[i]);
    }

    //print("threadnumber: $threadNumber");
    if(threadNumber == -1) {
      isolateQueue.add(pageID); //no free isolates -> will be send to queue
      //print("documents_notifier: isolatePageTiles5: added to isolateQueue");
      return;
    }

    final requestId = DateTime.now().microsecondsSinceEpoch;

    _requestIds[threadNumber] = requestId;

    runningIsolates[threadNumber] = true;
    pageIDsBeingRendered.add(pageID);

    //print("documents_notifier: isolatePageTiles: currentPageIDs: $currentPageIDs");

    _receivePorts[requestId] = ReceivePort();

    //print("spawn isolate");
    _isolates[requestId] = await Isolate.spawn(
      _isolateEntry1,
      _receivePorts[requestId]!.sendPort,
    );

    beginCounter++;
    //print("documents_notifier: listening...");
    _receivePorts[requestId]!.listen((message) {

      //print("documents_notifier: connection established");
      if (message is SendPort) {
        //print("documents_notifier: sending...");

        _sendPorts[requestId] = message;

        //print("documents_notifier: ${page.backgroundStrokes}");
        _sendPorts[requestId]?.send({
          "type": "start",
          "data": [page.pageHeight, page.pageWidth, page.strokes, page.backgroundStrokes, isolateRect, isolateScale, pageIndex, docID, requestId,],
        });
      } else {
        //print("documents_notifier: isolatePageTiles3: handle_message");
        _handleMessage2(docID, pageID, threadNumber, requestId, message);
      }
    });
  }

  Future<void> _handleMessage2(int docID, int pageID, int threadNumber, int requestID, dynamic message) async {
    final documents = [...state];
    final docIndex = documents.indexWhere((d) => d.docID == docID);
    //final doc = documents[docIndex];
    DocumentModel doc = [...state][docIndex];

    //print("documents_notifier: handleMessage2: finished render, pageID: $pageID, pages: ${doc.pages.map((p) => p.pageID).toList()}");


    _receivePorts[requestID]?.close();
    _isolates[requestID]?.kill(priority: Isolate.immediate);

    runningIsolates[threadNumber] = false;
    pageIDsBeingRendered.removeWhere((id) => id == pageID);
    //print("documents_notifier: _handleMessage: threads busy (by number): $runningIsolates");
    //print("documents_notifier: runningIsolates: $runningIsolates   pageIDsBeingRendered: $pageIDsBeingRendered    isolateQueue: $isolateQueue");


    currentPageIDs.removeWhere((n) => n == pageID);


    if(isolateQueue.isNotEmpty) {
      //print("documents_notifier: handleMessage: still items in queue...");
      isolatePageTiles5(docID, isolateQueue.first);
      //return; //if there is already another page in queue we can skip all this
    }

    if (message is SendPort) {
      _sendPorts[requestID] = message;
      //print("Worker ready $requestID");
      return;
    }
    else {


      try {
        if (message.aborted == true) {
          //print("documents_notifier: handleMessage: cancel received");
          return;
        }

        finishCounter++;

        //print(busy);
        //print("documents_notifier: beginCounter: $beginCounter, finishCounter : $finishCounter");

        final result = message;


        doc = [...state][docIndex];
        int pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);

        if (pageIndex == -1) {    //if page no longer exists abort
          //print("documents_notifier: handleMessage: page no longer exists, aborting...");
          return;
        }



        int counter = 0;
       // print("documents_notifier: backgroundsamewidths: ${result.backgroundSameWidths[0][0]}");
        //print("documents_notifier: handleMessage2: begin render");
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
          //print("documents_notifier: handleMessage: $pageID: $counter / ${result.tiles.length}");
          counter++;
          doc = [...state][docIndex];
          pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
          if (pageIndex == -1) {    //check again if page no longer exists abort
            //print("documents_notifier: handleMessage: page no longer exists, aborting...");
            return;
          }
        }



        doc = [...state][docIndex];
        pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);

        if (pageIndex == -1) {    //check again if page no longer exists abort
          //print("documents_notifier: handleMessage: page no longer exists, aborting...");
          return;
        }

        //print("documents_notifier: handleMessage2: finished render, pageID: $pageID, pageIndex: $pageIndex, pages: ${doc.pages.map((p) => p.pageID).toList()}");

        doc.pages[pageIndex].tiles = result.tiles;

        //print("documents_notifier: handleMessage: result, $runningIsolates   pageIDsBeingRendered: $pageIDsBeingRendered    isolateQueue: $isolateQueue");

        state = [
          for (int i = 0; i < state.length; i++)
            if (state[i].docID == result.docID)
              state[i].copyWith(pages: doc.pages)
            else
              state[i]
        ];
        //print(doc.pages.first.tiles.length);
      } finally {
        //_cancelPorts.remove(requestId);
      }
    }
  }




  final Map<int, Isolate?> _isolates = {};
  final Map<int, SendPort?> _sendPorts = {};
  final Map<int, ReceivePort?> _receivePorts = {};




  int beginCounter = 0;
  int finishCounter = 0;


  final Map<int, bool?> busy = {0: false, 1: false, 2: false, 3: false, 4: false};
  final Map<int, bool?> requested = {};

  List<int> requestedDocIDs = [0,0,0,0,0];
  List<int> requestedPageIDs = [0,0,0,0,0];
  List<int> currentPageIDs = [];

  void setPageColor(int docIndex, int pageIndex, Color color) {

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



  void setAllPageColors(int docIndex, Color color) {

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
    final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID);
    //doc.pages[pageIndex].newImage = value;
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
    final page = newPages[pageIndex];

    //print("meh");



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

    // ⚠️ WICHTIG: nur diese eine Page ersetzen
    final newPages = [...doc.pages];


    await newPages[pageIndex].updateTiles(strokes, erasedStrokeIDs, []);


    newPages[pageIndex].erasedIDs = [];

    docs[docIndex] = doc.copyWith(pages: newPages);

    state = docs;

    //print("documents_notifier: done updating");

  }


  void addCommands(int docID, List<Command> commands) {
    final newDocs = [...state];
    final docIndex = newDocs.indexWhere((d) => d.docID == docID);
    final doc = newDocs[docIndex];
    List<Command> newCommands = doc.commands;
    //print("docuemnts_notifier: added command$commands");

    for (int i = 0; i<commands.length; i++) {
      if (doc.commandIndex<doc.commands.length) {                                              //when not at top of the stack remove all commands after the current index:     [][][][][i][+]  |  [x][x][x][x]
        //print("notontop");
        doc.commands.removeRange(doc.commandIndex, doc.commands.length);
        //print(doc.commands.length);
      }

      if (doc.commands.length >= doc.maxAmountCommands) {                                           //remove oldest entry when max amount of undo steps is reached:     <--[] | [0][1][2][3][4]..[+]<--
        doc.commands.removeAt(0);  // remove oldest command
        //print("remove");
      }
      newCommands.add(commands[i]);
      doc.commandIndex=doc.commands.length;

    }

    newDocs[docIndex] = doc.copyWith(commands: newCommands, commandIndex: doc.commandIndex);

  }


  Future<void> undo(int docID) async {

    final docs = [...state];


    final docIndex = docs.indexWhere((d) => d.docID == docID);
    if (docIndex == -1) {
      return;
    }

    DocumentModel doc = docs[docIndex];
    //print("undo");

    List<Command> commands = doc.commands;


    Command command;

    int commandIndex = doc.commandIndex;



    for(final page in doc.pages){                               //current selections will be canceled when undo/redo is called
      setNewImage(doc.docID, page.pageID, false);
    }

    if (doc.commandIndex>0) {
      //print(doc.commandIndex);
      commandIndex = doc.commandIndex-1;
      command = commands[commandIndex];
      //print("undo at $commandIndex");
    }
    else {
      command=EmptyCommand();
    }

    //print("documents_notifier: undo $command");


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


  Future<void> redo(docID) async {
    //print("redo");
    final docs = [...state];
    //final doc = newDocs.firstWhere((d) => d.docID == docID,);
    final docIndex = docs.indexWhere((d) => d.docID == docID);
    DocumentModel doc = docs[docIndex];
    List<Command> commands = doc.commands;

    Command command;

    int commandIndex = doc.commandIndex;


    if (doc.commandIndex<doc.commands.length) {
      //print(doc.commandIndex);
      command = commands[commandIndex];
      commandIndex = doc.commandIndex+1;

    }
    else {
      command=EmptyCommand();
    }




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

    //commands.removeLast();
    final newDocs = [...state];





    newDocs[docIndex] = newDocs[docIndex].copyWith(commands: commands, commandIndex: commandIndex);

    state = newDocs;


  }


  Future<void> saveAsBnf(int docIndex) async {
    final docs = [...state];
    DocumentModel doc = docs[docIndex];
    //print("documents_notifier: saveAsBnf: ${doc.pathToFile.split('.').last}");
    await saveDoc2(doc.docID, doc.pages);
  }

  Future<List<PageModel>> loadPages2(String pathToFile, List<int> pageIDs, bool generateFirstPage,) async {
    if (pageIDs.isEmpty) return [];

    final file = File(pathToFile);

    final List<PageModel> pages = [];

    if (await file.exists()) {
      final bytes = await file.readAsBytes();

      if (bytes.length < 16) {
        throw Exception(
          'Invalid document: file too small',
        );
      }

      final data = ByteData.sublistView(bytes);

      // ============================================================
      // HEADER
      //
      // 0..7   = Version
      // 8..15  = Root Offset
      // ============================================================

      final version = data.getUint64(
        0,
        Endian.little,
      );

      if (version != 1) {
        throw Exception(
          'Unsupported document version: $version',
        );
      }

      final rootOffset = data.getUint64(
        8,
        Endian.little,
      );

      if (rootOffset + 32 > bytes.length) {
        throw Exception(
          'Invalid root offset: $rootOffset '
              '(file length: ${bytes.length})',
        );
      }

      // ============================================================
      // ROOT
      //
      // Root:
      //
      // 0..7   = Metadata Offset
      // 8..15  = Metadata Length
      // 16..23 = Index Offset
      // 24..31 = Index Length
      // ============================================================

      final root = ByteData.sublistView(
        bytes,
        rootOffset,
        rootOffset + 32,
      );

      final indexOffset = root.getUint64(
        16,
        Endian.little,
      );

      final indexLength = root.getUint64(
        24,
        Endian.little,
      );

      if (indexOffset + indexLength > bytes.length) {
        throw Exception(
          'Invalid index range: '
              'offset=$indexOffset, '
              'length=$indexLength, '
              'file length=${bytes.length}',
        );
      }

      if (indexLength < 4) {
        throw Exception(
          'Invalid index length: $indexLength',
        );
      }

      // ============================================================
      // INDEX
      //
      // [4 Bytes Index Count]
      //
      // Danach pro Eintrag:
      //
      // [8 Bytes PageID]
      // [8 Bytes Page Offset]
      // [8 Bytes Page Length]
      // ============================================================

      final indexCount = data.getUint32(
        indexOffset,
        Endian.little,
      );

      final expectedIndexLength =
          4 + indexCount * 24;

      if (indexLength != expectedIndexLength) {
        throw Exception(
          'Invalid index length: '
              'expected=$expectedIndexLength, '
              'actual=$indexLength',
        );
      }

      final pageOffsets = <int, int>{};
      final pageLengths = <int, int>{};

      var indexEntryOffset = indexOffset + 4;

      for (var i = 0; i < indexCount; i++) {
        final pageID = data.getUint64(
          indexEntryOffset,
          Endian.little,
        );

        final pageOffset = data.getUint64(
          indexEntryOffset + 8,
          Endian.little,
        );

        final pageLength = data.getUint64(
          indexEntryOffset + 16,
          Endian.little,
        );

        pageOffsets[pageID] = pageOffset;
        pageLengths[pageID] = pageLength;

        indexEntryOffset += 24;
      }

      // ============================================================
      // GEWÜNSCHTE PAGES LADEN
      // ============================================================

      for (final pageID in pageIDs) {
        final pageOffset = pageOffsets[pageID];
        final pageLength = pageLengths[pageID];

        if (pageOffset == null || pageLength == null) {
          continue;
        }

        // pageOffset zeigt auf:
        //
        // [8 Bytes Page Length]
        // [Page Daten]
        //
        // Deshalb +8.

        if (pageOffset + 8 + pageLength >
            bytes.length) {
          throw Exception(
            'Invalid page range: '
                'pageID=$pageID, '
                'offset=$pageOffset, '
                'length=$pageLength',
          );
        }

        final storedPageLength = data.getUint64(
          pageOffset,
          Endian.little,
        );

        if (storedPageLength != pageLength) {
          throw Exception(
            'Page length mismatch: '
                'pageID=$pageID, '
                'index=$pageLength, '
                'stored=$storedPageLength',
          );
        }

        final pageBytes = bytes.sublist(
          pageOffset + 8,
          pageOffset + 8 + pageLength,
        );

        final page = await PageModel.fromBytes(
          pageBytes,
        );

        pages.add(page);
      }
    } else if (generateFirstPage) {
      pages.add(
        PageModel(
          strokes: [],
          backgroundStrokes: [],
          images: [],
          pageWidth: 210,
          pageHeight: 297,
          pageColor: Colors.white,
          tiles: [[]],
        ),
      );
    }

    return pages;
  }



  Future<void> loadDoc2(String pathToFile, int docIndex,) async {
    final file = File(pathToFile);

    if (!await file.exists()) return;

    print(
      'documents_notifier: loadDoc2: $pathToFile',
    );

    // ============================================================
    // Datei lesen
    //
    // Wir lesen die Datei hier zwar komplett ein, laden aber
    // NICHT alle Pages als PageModel.
    //
    // Die Pages selbst werden später gezielt mit loadPages2()
    // geladen.
    // ============================================================

    final bytes = await file.readAsBytes();

    if (bytes.length < 16) {
      throw Exception(
        'Invalid document: file too small',
      );
    }

    final data = ByteData.sublistView(bytes);

    // ============================================================
    // HEADER
    //
    // 0..7   = Version
    // 8..15  = Root Offset
    // ============================================================

    final version = data.getUint64(
      0,
      Endian.little,
    );

    if (version != 1) {
      throw Exception(
        'Unsupported document version: $version',
      );
    }

    final rootOffset = data.getUint64(
      8,
      Endian.little,
    );

    print(
      'documents_notifier: loadDoc2: '
          'rootOffset=$rootOffset',
    );

    if (rootOffset + 32 > bytes.length) {
      throw Exception(
        'Invalid root offset: $rootOffset '
            '(file length: ${bytes.length})',
      );
    }

    // ============================================================
    // ROOT
    //
    // 0..7   = Metadata Offset
    // 8..15  = Metadata Length
    // 16..23 = Index Offset
    // 24..31 = Index Length
    // ============================================================

    final root = ByteData.sublistView(
      bytes,
      rootOffset,
      rootOffset + 32,
    );

    final metadataOffset = root.getUint64(
      0,
      Endian.little,
    );

    final metadataLength = root.getUint64(
      8,
      Endian.little,
    );

    if (metadataOffset + 8 + metadataLength >
        bytes.length) {
      throw Exception(
        'Invalid metadata range: '
            'offset=$metadataOffset '
            'length=$metadataLength '
            'file length=${bytes.length}',
      );
    }

    // ============================================================
    // METADATA
    //
    // Bei saveDoc3 wird gespeichert:
    //
    // [8 Bytes Metadata Length]
    // [JSON Metadata]
    // ============================================================

    final storedMetadataLength = data.getUint64(
      metadataOffset,
      Endian.little,
    );

    if (storedMetadataLength != metadataLength) {
      throw Exception(
        'Metadata length mismatch: '
            'root=$metadataLength '
            'stored=$storedMetadataLength',
      );
    }

    final metadataBytes = bytes.sublist(
      metadataOffset + 8,
      metadataOffset + 8 + metadataLength,
    );

    final metadata = jsonDecode(
      utf8.decode(metadataBytes),
    ) as Map<String, dynamic>;

    // ============================================================
    // DOCUMENT METADATA
    // ============================================================

    final defaultPageJson =
    metadata['defaultPage'] as Map<String, dynamic>?;

    final defaultPage = defaultPageJson != null
        ? await PageModel.fromJson(
      defaultPageJson,
    )
        : PageModel(
      strokes: [],
      backgroundStrokes: [],
      images: [],
      pageWidth: 297,
      pageHeight: 210,
      pageColor: Colors.white70,
      tiles: [[]],
    );

    final title =
        metadata['title'] as String? ?? '?';

    final author =
        metadata['author'] as String? ?? '?';

    final created = metadata['created'] != null
        ? DateTime.parse(
      metadata['created'] as String,
    )
        : DateTime.now();

    final pageHeights =
    ((metadata['pageHeights'] as List?) ?? [0.0])
        .map(
          (e) => (e as num).toDouble(),
    )
        .toList();

    final pageList =
    ((metadata['pageList'] as List?) ?? [])
        .map(
          (e) => (e as num).toInt(),
    )
        .toList();

    print(
      'documents_notifier: loadDoc2: '
          'pageList=$pageList',
    );

    print(
      'documents_notifier: loadDoc2: '
          'pageHeights=${pageHeights.length}',
    );

    // ============================================================
    // NUR DIE ERSTEN PAGES LADEN
    //
    // Genau wie bei loadDoc1().
    // ============================================================

    final loadIDs = <int>[];

    for (
    var i = 0;
    i < lazyLoadRange + 1;
    i++
    ) {
      if (i < pageList.length) {
        loadIDs.add(
          pageList[i],
        );
      }
    }

    print(
      'documents_notifier: loadDoc2: '
          'loading IDs=$loadIDs',
    );

    final pages = await loadPages2(
      pathToFile,
      loadIDs,
      true,
    );

    print(
      'documents_notifier: loadDoc2: '
          'loaded pages=${pages.length}',
    );

    // ============================================================
    // IDs entfernen, für die keine Page mehr existiert
    //
    // Das gleiche Verhalten wie bei loadDoc1().
    // ============================================================

    final actualIDs = pages
        .map(
          (page) => page.pageID,
    )
        .toList();

    final missing = loadIDs
        .where(
          (id) => !actualIDs.contains(id),
    )
        .toList();

    print(
      'documents_notifier: loadDoc2: '
          'missing IDs=$missing',
    );

    final cleanedPageList =
    List<int>.from(pageList);

    cleanedPageList.removeWhere(
          (id) => missing.contains(id),
    );

    // ============================================================
    // DOCUMENT MODEL
    // ============================================================

    final newDocuments = [...state];

    newDocuments[docIndex] = DocumentModel(
      pages: List.unmodifiable(
        pages,
      ),
      docBackgroundColor: Colors.purpleAccent,
      defaultPage: defaultPage,
      author: author,
      title: title,
      created: created,
      pageHeights: pageHeights,
      pageList: cleanedPageList,
    );

    newDocuments[docIndex].pathToFile =
        pathToFile;

    newDocuments[docIndex].currentPageIndex = 0;

    state = newDocuments;
  }




  bool _isSaving = false;
  List<PageModel> pagesToSaveQueue = [];

  Future<void> saveDoc2(
      int docID,
      List<PageModel> pagesToSave,
      ) async {
    if (pagesToSave.isEmpty) return;

    if (_isSaving) {
      pagesToSaveQueue.addAll(pagesToSave);
      return;
    }

    _isSaving = true;

    try {
      await _saveDoc2Internal(docID, pagesToSave);
    } finally {
      _isSaving = false;
    }

    if (pagesToSaveQueue.isNotEmpty) {
      final queuedPages = List<PageModel>.from(pagesToSaveQueue);
      pagesToSaveQueue.clear();
      await saveDoc2(docID, queuedPages);
    }
  }


  Future<void> _saveDoc2Internal(int docID, List<PageModel> pagesToSave) async {
    if (pagesToSaveQueue.isNotEmpty) {
      pagesToSaveQueue.addAll(pagesToSave);
      return;
    }

    if (pagesToSave.isEmpty) return;

    final documents = [...state];

    final docIndex = documents.indexWhere(
          (d) => d.docID == docID,
    );

    if (docIndex == -1) return;

    final doc = documents[docIndex];

    final file = File(doc.pathToFile);

    if (!await file.exists()) {
      return;
    }

    final raf = await file.open(
      mode: FileMode.append,
    );

    try {
      // ============================================================
      // 1. Dateilänge
      // ============================================================

      final fileLength = await raf.length();

      if (fileLength < 16) {
        throw Exception('Invalid document: file too small');
      }

      // ============================================================
      // 2. Header lesen
      //
      // 0..7   = Version
      // 8..15  = Root Offset
      // ============================================================

      await raf.setPosition(0);

      final headerBytes = await raf.read(16);

      if (headerBytes.length != 16) {
        throw Exception('Could not read document header');
      }

      final header = ByteData.sublistView(headerBytes);

      final version = header.getUint64(
        0,
        Endian.little,
      );

      if (version != 1) {
        throw Exception(
          'Unsupported document version: $version',
        );
      }

      final oldRootOffset = header.getUint64(
        8,
        Endian.little,
      );

      if (oldRootOffset + 32 > fileLength) {
        throw Exception(
          'Invalid root offset: $oldRootOffset',
        );
      }

      // ============================================================
      // 3. Root lesen
      // ============================================================

      await raf.setPosition(oldRootOffset);

      final rootBytes = await raf.read(32);

      if (rootBytes.length != 32) {
        throw Exception('Could not read root');
      }

      final oldRoot = ByteData.sublistView(rootBytes);

      final oldIndexOffset = oldRoot.getUint64(
        16,
        Endian.little,
      );

      final oldIndexLength = oldRoot.getUint64(
        24,
        Endian.little,
      );

      // ============================================================
      // 4. Index lesen
      //
      // Nur der Index wird komplett gelesen.
      // ============================================================

      if (oldIndexOffset + oldIndexLength > fileLength) {
        throw Exception('Invalid old index range');
      }

      if (oldIndexLength < 4) {
        throw Exception('Invalid old index length');
      }

      await raf.setPosition(oldIndexOffset);

      final oldIndexBytes = await raf.read(
        oldIndexLength,
      );

      if (oldIndexBytes.length != oldIndexLength) {
        throw Exception('Could not read old index');
      }

      final oldIndexData = ByteData.sublistView(
        oldIndexBytes,
      );

      final indexCount = oldIndexData.getUint32(
        0,
        Endian.little,
      );

      final expectedIndexLength =
          4 + indexCount * 24;

      if (oldIndexLength != expectedIndexLength) {
        throw Exception(
          'Invalid old index length: '
              'expected=$expectedIndexLength, '
              'actual=$oldIndexLength',
        );
      }

      final index = <int, ({int offset, int length})>{};

      var indexPosition = 4;

      for (var i = 0; i < indexCount; i++) {
        final pageID = oldIndexData.getUint64(
          indexPosition,
          Endian.little,
        );

        final pageOffset = oldIndexData.getUint64(
          indexPosition + 8,
          Endian.little,
        );

        final pageLength = oldIndexData.getUint64(
          indexPosition + 16,
          Endian.little,
        );

        index[pageID] = (
        offset: pageOffset,
        length: pageLength,
        );

        indexPosition += 24;
      }

      // ============================================================
      // 5. Position am Dateiende
      // ============================================================

      var currentOffset = fileLength;

      bool anythingChanged = false;

      // ============================================================
      // 6. Pages prüfen und ggf. ans Ende schreiben
      // ============================================================

      for (final page in pagesToSave) {
        if (page.isTemp) {
          continue;
        }

        final pageBytes = await page.toBytes();

        final oldPageInfo = index[page.pageID];

        bool pageChanged = true;

        if (oldPageInfo != null) {
          final oldDataOffset =
              oldPageInfo.offset + 8;

          final oldDataLength =
              oldPageInfo.length;

          if (oldDataOffset + oldDataLength <= fileLength) {
            // Nur die betreffende Page lesen.
            await raf.setPosition(oldDataOffset);

            final oldPageBytes = await raf.read(
              oldDataLength,
            );

            if (oldPageBytes.length == oldDataLength) {
              pageChanged = !_bytesEqual(
                oldPageBytes,
                pageBytes,
              );
            }
          }
        }

        // Page unverändert
        if (!pageChanged) {
          continue;
        }

        anythingChanged = true;

        // ----------------------------------------------------------
        // Neue Page ans Ende schreiben
        // ----------------------------------------------------------

        final pageOffset = currentOffset;

        final pageLengthBytes = ByteData(8)
          ..setUint64(
            0,
            pageBytes.length,
            Endian.little,
          );

        await raf.setPosition(currentOffset);

        await raf.writeFrom(
          pageLengthBytes.buffer.asUint8List(),
        );

        currentOffset += 8;

        await raf.writeFrom(pageBytes);

        currentOffset += pageBytes.length;

        // Neuer Index-Eintrag
        index[page.pageID] = (
        offset: pageOffset,
        length: pageBytes.length,
        );
      }

      if (!anythingChanged) {
        return;
      }

      // ============================================================
      // 7. Metadata
      // ============================================================

      final metadata = {
        'title': doc.title,
        'author': doc.author,
        'created': doc.created.toIso8601String(),
        'modified': DateTime.now().toIso8601String(),
        'defaultPage': doc.defaultPage.toJson(),
        'pageHeights': doc.pageHeights,
        'pageList': doc.pageList,
      };

      final metadataBytes = utf8.encode(
        jsonEncode(metadata),
      );

      final metadataOffset = currentOffset;

      final metadataLengthBytes = ByteData(8)
        ..setUint64(
          0,
          metadataBytes.length,
          Endian.little,
        );

      await raf.setPosition(currentOffset);

      await raf.writeFrom(
        metadataLengthBytes.buffer.asUint8List(),
      );

      currentOffset += 8;

      await raf.writeFrom(metadataBytes);

      currentOffset += metadataBytes.length;

      // ============================================================
      // 8. Neuer Index
      // ============================================================

      final indexOffset = currentOffset;

      final indexCountBytes = ByteData(4)
        ..setUint32(
          0,
          index.length,
          Endian.little,
        );

      await raf.writeFrom(
        indexCountBytes.buffer.asUint8List(),
      );

      currentOffset += 4;

      for (final entry in index.entries) {
        final entryBytes = ByteData(24)
          ..setUint64(
            0,
            entry.key,
            Endian.little,
          )
          ..setUint64(
            8,
            entry.value.offset,
            Endian.little,
          )
          ..setUint64(
            16,
            entry.value.length,
            Endian.little,
          );

        await raf.writeFrom(
          entryBytes.buffer.asUint8List(),
        );

        currentOffset += 24;
      }

      final indexLength =
          currentOffset - indexOffset;

      // ============================================================
      // 9. Neuer Root
      // ============================================================

      final newRootOffset = currentOffset;

      final newRoot = ByteData(32)
        ..setUint64(
          0,
          metadataOffset,
          Endian.little,
        )
        ..setUint64(
          8,
          metadataBytes.length,
          Endian.little,
        )
        ..setUint64(
          16,
          indexOffset,
          Endian.little,
        )
        ..setUint64(
          24,
          indexLength,
          Endian.little,
        );

      await raf.writeFrom(
        newRoot.buffer.asUint8List(),
      );

      currentOffset += 32;

      // ============================================================
      // 10. Root-Pointer im Header aktualisieren
      //
      // Nur 8 Bytes werden am Anfang geändert.
      // ============================================================

      await raf.setPosition(8);

      final rootPointer = ByteData(8)
        ..setUint64(
          0,
          newRootOffset,
          Endian.little,
        );

      await raf.writeFrom(
        rootPointer.buffer.asUint8List(),
      );

      // ============================================================
      // 11. Flush
      // ============================================================

      await raf.flush();
    } finally {
      await raf.close();
    }

    // ============================================================
    // 12. Queue verarbeiten
    // ============================================================

    if (pagesToSaveQueue.isNotEmpty) {
      final newPagesToSave = pagesToSaveQueue
          .map((page) => page.copyWith())
          .toList();

      pagesToSaveQueue = [];

      await saveDoc2(
        docID,
        newPagesToSave,
      );
    }
  }






  bool _bytesEqual(List<int> a, List<int> b,) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }



  Future<void> compactDoc(int docID) async {


    final documents = [...state];

    final docIndex = documents.indexWhere(
          (d) => d.docID == docID,
    );

    if (docIndex == -1) {
      throw Exception('Document not found: $docID');
    }

    final doc = documents[docIndex];
    final file = File(doc.pathToFile);

    if (!await file.exists()) {
      throw Exception('Document file does not exist');
    }

    // ============================================================
    // 1. Komplette Datei lesen
    // ============================================================

    final oldBytes = await file.readAsBytes();

    if (oldBytes.length < 16) {
      throw Exception('Invalid document');
    }

    print('========================================');
    print('COMPACTION START');
    print('file: ${file.path}');
    print('old file size: ${oldBytes.length}');
    print('========================================');

    final oldData = ByteData.sublistView(oldBytes);

    final version = oldData.getUint64(
      0,
      Endian.little,
    );

    if (version != 1) {
      throw Exception(
        'Unsupported document version: $version',
      );
    }

    final oldRootOffset = oldData.getUint64(
      8,
      Endian.little,
    );

    if (oldRootOffset + 32 > oldBytes.length) {
      throw Exception('Invalid root offset');
    }

    // ============================================================
    // 2. Aktuellen Root lesen
    // ============================================================

    final root = ByteData.sublistView(
      oldBytes,
      oldRootOffset,
      oldRootOffset + 32,
    );

    final metadataOffset = root.getUint64(
      0,
      Endian.little,
    );

    final metadataLength = root.getUint64(
      8,
      Endian.little,
    );

    final indexOffset = root.getUint64(
      16,
      Endian.little,
    );

    final indexLength = root.getUint64(
      24,
      Endian.little,
    );

    // ============================================================
    // 3. Aktuellen Index lesen
    // ============================================================

    if (indexOffset + indexLength > oldBytes.length) {
      throw Exception('Invalid index range');
    }

    final indexData = ByteData.sublistView(
      oldBytes,
      indexOffset,
      indexOffset + indexLength,
    );

    if (indexLength < 4) {
      throw Exception('Invalid index length');
    }

    final indexCount = indexData.getUint32(
      0,
      Endian.little,
    );

    if (indexLength != 4 + indexCount * 24) {
      throw Exception('Invalid index length');
    }

    final oldIndex =
    <int, ({int offset, int length})>{};

    var position = 4;

    for (var i = 0; i < indexCount; i++) {
      final pageID = indexData.getUint64(
        position,
        Endian.little,
      );

      final pageOffset = indexData.getUint64(
        position + 8,
        Endian.little,
      );

      final pageLength = indexData.getUint64(
        position + 16,
        Endian.little,
      );

      oldIndex[pageID] = (
      offset: pageOffset,
      length: pageLength,
      );

      position += 24;
    }

    // ============================================================
    // 4. Neue Datei
    // ============================================================

    final builder = BytesBuilder();

    // Header reservieren
    //
    // 0..7   Version
    // 8..15  Root Offset
    //
    final header = ByteData(16)
      ..setUint64(
        0,
        1,
        Endian.little,
      )
      ..setUint64(
        8,
        0,
        Endian.little,
      );

    builder.add(
      header.buffer.asUint8List(),
    );

    var currentOffset = 16;

    // Neuer Index
    final newIndex =
    <int, ({int offset, int length})>{};

    // ============================================================
    // 5. NUR aktuell verwendete Pages übernehmen
    // ============================================================

    for (final entry in oldIndex.entries) {
      final pageID = entry.key;
      final oldPageOffset = entry.value.offset;
      final pageLength = entry.value.length;

      // Offset zeigt auf das Length-Feld.
      final pageDataOffset = oldPageOffset + 8;

      final pageEnd =
          pageDataOffset + pageLength;

      if (oldPageOffset + 8 > oldBytes.length ||
          pageEnd > oldBytes.length) {
        throw Exception(
          'Invalid page range for pageID=$pageID',
        );
      }

      // Zusätzlich prüfen, ob das gespeicherte
      // Length-Feld stimmt.
      final storedLengthData =
      ByteData.sublistView(
        oldBytes,
        oldPageOffset,
        oldPageOffset + 8,
      );

      final storedLength =
      storedLengthData.getUint64(
        0,
        Endian.little,
      );

      if (storedLength != pageLength) {
        throw Exception(
          'Page length mismatch for pageID=$pageID',
        );
      }

      // Neue Position dieser Page
      final newPageOffset = currentOffset;

      // Length
      final lengthBytes = ByteData(8)
        ..setUint64(
          0,
          pageLength,
          Endian.little,
        );

      builder.add(
        lengthBytes.buffer.asUint8List(),
      );

      // Page-Daten
      builder.add(
        Uint8List.sublistView(
          oldBytes,
          pageDataOffset,
          pageEnd,
        ),
      );

      currentOffset += 8 + pageLength;

      // Neuer Offset für den neuen Index
      newIndex[pageID] = (
      offset: newPageOffset,
      length: pageLength,
      );
    }

    // ============================================================
    // 6. Aktuelle Metadata übernehmen
    // ============================================================

    final metadataEnd =
        metadataOffset +
            8 +
            metadataLength;

    if (metadataOffset + 8 > oldBytes.length ||
        metadataEnd > oldBytes.length) {
      throw Exception(
        'Invalid metadata range',
      );
    }

    final newMetadataOffset = currentOffset;

    final metadataLengthBytes = ByteData(8)
      ..setUint64(
        0,
        metadataLength,
        Endian.little,
      );

    builder.add(
      metadataLengthBytes.buffer.asUint8List(),
    );

    builder.add(
      Uint8List.sublistView(
        oldBytes,
        metadataOffset + 8,
        metadataEnd,
      ),
    );

    currentOffset += 8 + metadataLength;

    // ============================================================
    // 7. Neuen Index schreiben
    // ============================================================

    final newIndexOffset = currentOffset;

    final countBytes = ByteData(4)
      ..setUint32(
        0,
        newIndex.length,
        Endian.little,
      );

    builder.add(
      countBytes.buffer.asUint8List(),
    );

    currentOffset += 4;

    for (final entry in newIndex.entries) {
      final bytes = ByteData(24)
        ..setUint64(
          0,
          entry.key,
          Endian.little,
        )
        ..setUint64(
          8,
          entry.value.offset,
          Endian.little,
        )
        ..setUint64(
          16,
          entry.value.length,
          Endian.little,
        );

      builder.add(
        bytes.buffer.asUint8List(),
      );

      currentOffset += 24;
    }

    final newIndexLength =
        currentOffset - newIndexOffset;

    // ============================================================
    // 8. Neuen Root schreiben
    // ============================================================

    final newRootOffset = currentOffset;

    final newRoot = ByteData(32)
      ..setUint64(
        0,
        newMetadataOffset,
        Endian.little,
      )
      ..setUint64(
        8,
        metadataLength,
        Endian.little,
      )
      ..setUint64(
        16,
        newIndexOffset,
        Endian.little,
      )
      ..setUint64(
        24,
        newIndexLength,
        Endian.little,
      );

    builder.add(
      newRoot.buffer.asUint8List(),
    );

    // ============================================================
    // 9. Root-Pointer im neuen Header setzen
    // ============================================================

    final newBytes = builder.takeBytes();

    final newData =
    ByteData.sublistView(newBytes);

    newData.setUint64(
      8,
      newRootOffset,
      Endian.little,
    );

    // ============================================================
    // 10. Neue Datei schreiben
    // ============================================================

    final tempFile = File(
      '${file.path}.compact.tmp',
    );

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await tempFile.writeAsBytes(
      newBytes,
      flush: true,
    );

    // ============================================================
    // 11. Alte Datei ersetzen
    // ============================================================

    await file.delete();

    await tempFile.rename(
      file.path,
    );

    print(
      'compactDoc: '
          '${oldBytes.length} -> ${newBytes.length} Bytes '
          '(gespart: ${oldBytes.length - newBytes.length})',
    );


    var referencedPageBytes = 0;

    for (final entry in oldIndex.entries) {
      referencedPageBytes += 8 + entry.value.length;
    }

    final referencedMetadataBytes =
        8 + metadataLength;

    final referencedIndexBytes =
        4 + oldIndex.length * 24;

    final referencedRootBytes = 32;

    final referencedBytes =
        16 +
            referencedPageBytes +
            referencedMetadataBytes +
            referencedIndexBytes +
            referencedRootBytes;

    final garbageBytes =
        oldBytes.length - referencedBytes;

    print('----------------------------------------');
    print('index pages: $indexCount');
    print('referenced pages: $referencedPageBytes bytes');
    print('metadata: $referencedMetadataBytes bytes');
    print('index: $referencedIndexBytes bytes');
    print('root: $referencedRootBytes bytes');
    print('minimum possible size: $referencedBytes');
    print('actual old size: ${oldBytes.length}');
    print('GARBAGE: $garbageBytes');
    print('----------------------------------------');

  }

}


void _isolateEntry1(SendPort sendPort) async {
  bool cancelled = false;

  //int? currentRequestId;
  //Set<int> cancels = {};



  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {


    if (msg['type'] == 'cancel') {
      //cancels.add(msg['id']);
      cancelled = true;
      //print("Cancel received in isolate ");
    }
    else if (msg['type'] == 'start') {


      //print("documents_notifier: begin calcualting...");

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
      final int requestId = args[8];

      //currentRequestId = requestId;

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
            //print("aborting in $requestId, row: $row");
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


      //print("documents_notifier: calculation finished");
      sendPort.send((aborted: false, tiles: tiles, tileStrokes: tileStrokes, sameWidths: sameWidths, rights: rights, lefts: lefts, backgroundTileStrokes: backgroundTileStrokes, backgroundSameWidths: backgroundSameWidths, backgroundRights: backgroundRights, backgroundLefts: backgroundLefts, scale: scale, pageIndex: pageIndex, docID : docID));

    }
  });
}