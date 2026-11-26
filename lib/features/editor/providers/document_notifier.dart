import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../data/document_store.dart';
import '../models/commands/command.dart';
import '../models/commands/modify_elements_command.dart';
import '../models/commands/modify_pages_command.dart';
import '../models/commands/undo_history.dart';
import '../models/page/document_model.dart';
import '../models/page/image_model.dart';
import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import '../rendering/page_renderer.dart';
import '../rendering/rust_page_renderer.dart';
import '../rendering/mesh_page_renderer.dart';
import 'open_documents_notifier.dart';

/// State of one open document (D2). Created by [OpenDocumentsNotifier.open], which also keeps it
/// alive until the document is closed; widgets watch `documentProvider(docID)`.
///
/// Responsibilities: page and element changes with undo/redo, the lazy-loading window (only the
/// pages around the current page are in memory), saving through the document's [DocumentStore],
/// and reporting changes of loaded pages to the [PageRenderer].
///
/// Async methods check [Ref.mounted] after every await: the document can be closed meanwhile.
class DocumentNotifier extends Notifier<DocumentModel> {
  DocumentNotifier(this.docID);

  final int docID;
  late DocumentStore _store;

  /// Pages within this distance of the current page are loaded.
  static const int lazyLoadRange = 1;

  /// Vertical gap above and below each page (in mm), used for the placeholder height.
  static const double distanceBetweenPages = 12;

  @override
  DocumentModel build() {
    final opened = ref.read(openDocumentsProvider.notifier).takeOpened(docID);
    _store = opened.store;
    print("document_notifier: doc $docID uses the ${switch (renderer) { MeshPageRenderer() => 'mesh', RustPageRenderer() => 'Rust tile', _ => 'Dart' }} renderer");
    return opened.document;
  }

  PageKey _key(int pageID) => (docID: docID, pageID: pageID);

  /// The renderer of this document, chosen when it is opened (switching needs a reopen).
  late final PageRenderer renderer = ref.read(meshRendererEnabledProvider)
      ? ref.read(meshPageRendererProvider)
      : ref.read(rustRendererEnabledProvider)
          ? ref.read(rustPageRendererProvider)
          : ref.read(dartPageRendererProvider);

  PageRenderer get _renderer => renderer;

  // ============================================================
  // Elements (strokes, images)
  // ============================================================

  /// Adds and removes strokes/images on page [pageID] and records it for undo.
  /// Works on pages outside the loaded window too (they are read from and saved to the file).
  Future<void> modifyElements(int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<ImageModel> removeImages) async {
    final page = await _currentPage(pageID);
    if (page == null || !ref.mounted) {
      print("document_notifier: modifyElements: page $pageID not found");
      return;
    }

    addStrokes = [for (final s in addStrokes) s.frozen()];     //the command and the page share these
    final removeStrokes = page.strokes.where((s) => removeStrokeIDs.contains(s.strokeID)).toList();
    final removeImageIDs = removeImages.map((s) => s.imageID).toList();

    _addCommands([ModifyElementsCommand(addedStrokes: addStrokes, addedImages: addImages, removedStrokes: removeStrokes, removedImages: removeImages, pageID: pageID)]);
    await modifyElementsExecute(pageID, addStrokes, addImages, removeStrokeIDs, removeImageIDs);
  }

  /// Applies a stroke/image change to page [pageID] without recording it (used by undo/redo).
  ///
  /// The change is idempotent: elements are removed by ID, and added elements replace elements
  /// with the same ID. That allows applying it to the file and, if the page got loaded meanwhile,
  /// to the loaded window as well.
  Future<void> modifyElementsExecute(int pageID, List<Stroke> addStrokes, List<ImageModel> addImages, List<int> removeStrokeIDs, List<int> removeImageIDs) async {
    final addedStrokeIDs = {for (final s in addStrokes) s.strokeID};
    final addedImageIDs = {for (final i in addImages) i.imageID};
    PageModel apply(PageModel page) => page.copyWith(
      images: [...page.images.where((img) => !removeImageIDs.contains(img.imageID) && !addedImageIDs.contains(img.imageID)), ...addImages],
      strokes: [...page.strokes.where((stroke) => !removeStrokeIDs.contains(stroke.strokeID) && !addedStrokeIDs.contains(stroke.strokeID)), ...addStrokes],
    );

    if (state.loadedPage(pageID) == null) {
      // Not in the loaded window: change the stored page.
      final page = await _currentPage(pageID);
      if (!ref.mounted) return;
      if (page == null) {
        print("document_notifier: modifyElementsExecute: page $pageID not found");
        return;
      }
      await saveDoc([apply(page)]);
      if (!ref.mounted) return;
    }

    final loaded = state.loadedPage(pageID);
    if (loaded != null) {
      _replacePage(apply(loaded));
      await _renderer.updateStrokes(_key(pageID), state.loadedPage(pageID)!, addStrokes, removeStrokeIDs);
    }
  }

  /// Current version of page [pageID]: the loaded one, or the one stored in the file.
  /// Waits for a page of the window that is still loading. Returns null if there is no such page.
  Future<PageModel?> _currentPage(int pageID) async {
    if (state.pages.any((p) => p.pageID == pageID && p.isTemp)) {
      await loadWindowPages();
      if (!ref.mounted) return null;
    }
    return state.loadedPage(pageID) ?? (await _store.loadPages([pageID])).firstOrNull;
  }

  void _replacePage(PageModel page) {
    state = state.copyWith(pages: [
      for (final p in state.pages) p.pageID == page.pageID ? page : p,
    ]);
  }

  // ============================================================
  // Pages
  // ============================================================

  /// Inserts [addPages] at [addPageIndexes] (positions in the page list) and removes
  /// [removePageIDs], and records it for undo.
  Future<void> modifyPages(List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async {
    // Give added pages fresh IDs if their ID is already in use, so the command stored for
    // undo/redo and the state contain the same IDs.
    addPages = _withUniquePageIDs(state, addPages);

    // Remember where each removed page was in pageList (the whole document, not the loaded
    // window in pages), so undo re-inserts it at the same position.
    final removePages = <PageModel>[];
    final removePageIndexes = <int>[];
    for (final id in removePageIDs) {
      final position = state.pageList.indexOf(id);
      if (position == -1) continue;
      final page = await _currentPage(id);        //loaded or read from the file, for undo
      if (!ref.mounted) return;
      if (page == null) continue;
      removePages.add(page);
      removePageIndexes.add(position);
    }

    _addCommands([ModifyPagesCommand(addPages: addPages, addPageIndexes: addPageIndexes, removePages: removePages, removePageIndexes: removePageIndexes)]);
    await modifyPagesExecute(addPages, addPageIndexes, removePageIDs);
  }

  /// Applies a page change without recording it (used by undo/redo).
  Future<void> modifyPagesExecute(List<PageModel> addPages, List<int> addPageIndexes, List<int> removePageIDs) async {
    final doc = state;
    addPages = _withUniquePageIDs(doc, addPages);         //duplicate page IDs cause duplicate widget keys (red screen)
    print("document_notifier: modifyPagesExecute: add ${addPages.map((p) => p.pageID).toList()} at $addPageIndexes, remove $removePageIDs, pages: ${doc.pageList.length}");

    final pages = [...doc.pages];
    final pageHeights = [...doc.pageHeights];
    var pageList = [...doc.pageList];

    // addPageIndexes are positions in pageList (the whole document). pages is only the loaded
    // window, so the page is just appended there; setCurrentPageIndex below rebuilds the window in
    // pageList order (and saves pages that end up outside of it).
    for (int i = 0; i < addPageIndexes.length; i++) {
      final position = addPageIndexes[i].clamp(0, pageList.length);
      pages.add(addPages[i]);
      pageHeights.insert(position, addPages[i].pageHeight);
      pageList.insert(position, addPages[i].pageID);
    }

    final indices = removePageIDs
        .map((id) => pageList.indexOf(id))
        .where((index) => index != -1)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in indices) {
      pageHeights.removeAt(index);
    }
    pageList = pageList.where((id) => !removePageIDs.contains(id)).toList();

    state = doc.copyWith(
      pages: pages.where((page) => !removePageIDs.contains(page.pageID)).toList(),
      pageList: pageList,
      pageHeights: pageHeights,
    );

    final currentPage = doc.currentPageIndex.clamp(0, pageList.isEmpty ? 0 : pageList.length - 1);
    await setCurrentPageIndex(currentPage);
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
            print("document_notifier: _withUniquePageIDs: duplicate page ID ${p.pageID}, new ID ${newPage.pageID}");
            return newPage;
          }(),
    ];
  }

  // ============================================================
  // Lazy loading
  // ============================================================

  /// Moves the loaded window to [currentPage] (a position in the page list): pages leaving the
  /// window are saved and dropped from memory, new pages are added as placeholders and loaded in
  /// the background.
  Future<void> setCurrentPageIndex(int currentPage) async {
    final doc = state;

    final newPages = <PageModel>[];
    for (int i = currentPage - lazyLoadRange; i < currentPage + lazyLoadRange + 1; i++) {
      if (i < 0 || i >= doc.pageList.length) continue;
      final id = doc.pageList[i];
      newPages.add(doc.pages.where((p) => p.pageID == id).firstOrNull ?? PageModel(isTemp: true, pageID: id));
    }

    final removePages = doc.pages.where((page) => !newPages.contains(page)).toList();
    unawaited(saveDoc(removePages));         //pages leaving the loaded window
    _renderer.hidePages(removePages.map((p) => _key(p.pageID)));

    double placeholderHeight = 0;
    for (int i = 0; i < currentPage - lazyLoadRange && i < doc.pageHeights.length; i++) {
      placeholderHeight += doc.pageHeights[i] + 2 * distanceBetweenPages;
    }

    state = doc.copyWith(
      placeholderHeight: placeholderHeight,
      currentPageIndex: currentPage,
      pages: newPages,
    );

    unawaited(loadWindowPages());          //load pages in the background
  }

  /// Loads the placeholder pages of the window from the file and shows all loaded pages of the
  /// window in the renderer (it skips pages that are rendered already).
  Future<void> loadWindowPages() async {
    final pagesToLoad = <int>[];
    final toShow = <PageModel>[];
    for (final page in state.pages) {
      if (page.isTemp) {
        pagesToLoad.add(page.pageID);
      } else {
        toShow.add(page);
      }
    }

    final loadedByID = {for (final p in await _store.loadPages(pagesToLoad)) p.pageID: p};
    if (!ref.mounted) return;

    // The state may have changed while the pages were loading (undo/redo, pages added or removed,
    // window moved). Apply the loaded pages to the current state, replacing only placeholders.
    if (loadedByID.isNotEmpty) {
      state = state.copyWith(pages: [
        for (final page in state.pages)
          if (page.isTemp && loadedByID[page.pageID] != null) loadedByID[page.pageID]! else page,
      ]);
      toShow.addAll(loadedByID.values.where((p) => state.loadedPage(p.pageID) == p));
    }

    for (final page in toShow) {
      // A page shown earlier may have changed while the pages were loading.
      final current = state.loadedPage(page.pageID);
      if (current != null) _renderer.showPage(_key(page.pageID), current);
    }
  }

  /// Renders all loaded pages from scratch (after page size changes).
  Future<void> _resizeAllLoadedPages() async {
    for (final page in state.pages) {
      if (page.isTemp) continue;
      await _renderer.resizePage(_key(page.pageID), page);
      if (!ref.mounted) return;
    }
  }

  // ============================================================
  // Page setup (loaded pages only, not undoable; see roadmap)
  // ============================================================

  /// Applies [change] to every loaded page and keeps [DocumentModel.pageHeights] in sync.
  void _changeLoadedPages(PageModel Function(PageModel page) change, {Color? docBackgroundColor}) {
    final pages = [for (final p in state.pages) p.isTemp ? p : change(p)];
    final heights = [...state.pageHeights];
    for (final page in pages) {
      final index = state.pageList.indexOf(page.pageID);
      if (!page.isTemp && index != -1 && index < heights.length) heights[index] = page.pageHeight;
    }
    state = state.copyWith(pages: pages, pageHeights: heights, docBackgroundColor: docBackgroundColor);
  }

  Future<void> setAllPageSizes(double width, double height) async {
    _changeLoadedPages((p) => p.copyWith(pageWidth: width, pageHeight: height));
    await _resizeAllLoadedPages();
  }

  Future<void> setPageSize(int pageID, double width, double height) async {
    _changeLoadedPages((p) => p.pageID == pageID ? p.copyWith(pageWidth: width, pageHeight: height) : p);
    final page = state.loadedPage(pageID);
    if (page == null) return;
    await _renderer.resizePage(_key(pageID), page);
  }

  void setPageColor(int pageID, Color color) =>
      _changeLoadedPages((p) => p.pageID == pageID ? p.copyWith(pageColor: color) : p);

  void setAllPageColors(Color color) =>
      _changeLoadedPages((p) => p.copyWith(pageColor: color), docBackgroundColor: color);

  Future<void> setAllBackgroundSpacing(List<double> horizontalSpaces, List<double> verticalSpaces, Color strokeColor, double strokeWidth) async {
    for (final page in state.pages) {
      if (page.isTemp) continue;
      await setBackgroundSpacing(page.pageID, horizontalSpaces, verticalSpaces, strokeColor, strokeWidth);
      if (!ref.mounted) return;
    }
  }

  Future<void> setBackgroundSpacing(int pageID, List<double> horizontalSpaces, List<double> verticalSpaces, Color strokeColor, double strokeWidth) async {
    final page = state.loadedPage(pageID);
    if (page == null) return;
    final newPage = page.withBackgroundSpacing(horizontalSpaces, verticalSpaces, strokeColor, strokeWidth);
    _replacePage(newPage);
    await _renderer.updateBackground(_key(pageID), newPage);
  }

  void setDefaultPage(PageModel newDefaultPage) => state = state.copyWith(defaultPage: newDefaultPage);

  // ============================================================
  // Undo / redo
  // ============================================================

  void _addCommands(List<Command> commands) {
    final history = pushCommands((commands: state.commands, index: state.commandIndex), commands, state.maxAmountCommands);
    state = state.copyWith(commands: history.commands, commandIndex: history.index);
  }

  /// True while an undo or redo runs. Both read the command index, await the page changes and
  /// then write the index back, so a second call during that time would repeat the same command.
  bool _undoRedoRunning = false;

  Future<void> undo() => _exclusive(() async {
    final doc = state;
    if (doc.commandIndex <= 0) return;
    final command = doc.commands[doc.commandIndex - 1];
    print("document_notifier: undo: ${command.runtimeType} at ${doc.commandIndex - 1} (commands: ${doc.commands.length})");

    if (command is ModifyElementsCommand) {
      await modifyElementsExecute(command.pageID, command.removedStrokes, command.removedImages,
          [for (final s in command.addedStrokes) s.strokeID], [for (final i in command.addedImages) i.imageID]);
    } else if (command is ModifyPagesCommand) {
      await modifyPagesExecute(command.removePages, command.removePageIndexes,
          [for (final p in command.addPages) p.pageID]);
    }
    if (ref.mounted) state = state.copyWith(commandIndex: doc.commandIndex - 1);
  });

  Future<void> redo() => _exclusive(() async {
    final doc = state;
    if (doc.commandIndex >= doc.commands.length) return;
    final command = doc.commands[doc.commandIndex];
    print("document_notifier: redo: ${command.runtimeType} at ${doc.commandIndex} (commands: ${doc.commands.length})");

    if (command is ModifyElementsCommand) {
      await modifyElementsExecute(command.pageID, command.addedStrokes, command.addedImages,
          [for (final s in command.removedStrokes) s.strokeID], [for (final i in command.removedImages) i.imageID]);
    } else if (command is ModifyPagesCommand) {
      await modifyPagesExecute(command.addPages, command.addPageIndexes,
          [for (final p in command.removePages) p.pageID]);
    }
    if (ref.mounted) state = state.copyWith(commandIndex: doc.commandIndex + 1);
  });

  Future<void> _exclusive(Future<void> Function() action) async {
    if (_undoRedoRunning) return;
    _undoRedoRunning = true;
    try {
      await action();
    } finally {
      _undoRedoRunning = false;
    }
  }

  // ============================================================
  // Saving
  // ============================================================

  /// Saves [pages] (unchanged ones are skipped) and the document metadata.
  Future<void> saveDoc(List<PageModel> pages) =>
      _store.save(pages, () => ref.mounted ? state.toMetadata() : null);

  /// Saves all loaded pages.
  Future<void> save() => saveDoc(state.pages);

  /// Saves the loaded pages and closes the file (compacting it if worthwhile). Called by
  /// [OpenDocumentsNotifier.close]; the document can't be saved afterwards.
  Future<void> closeStore() async {
    await save();
    await _store.close(state.pageList.toSet());
  }
}

final documentProvider = NotifierProvider.autoDispose.family<DocumentNotifier, DocumentModel, int>(DocumentNotifier.new);
