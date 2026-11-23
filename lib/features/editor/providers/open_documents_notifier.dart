import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/document_store.dart';
import '../models/page/document_model.dart';
import '../models/page/page_model.dart';
import '../rendering/page_tiles.dart';
import 'document_notifier.dart';

/// The open documents (their docIDs, in opening order). Opening reads the file and creates the
/// document's `documentProvider(docID)`; closing saves and closes the file.
///
/// Tabs (P4-03 goal) only need UI on top of this and [activeDocumentProvider].
class OpenDocumentsNotifier extends Notifier<List<int>> {
  /// Documents read by [open] whose provider hasn't been built yet.
  final Map<int, ({DocumentModel document, DocumentStore store})> _opened = {};

  /// Keeps each open document's (auto-disposing) provider alive until [close].
  final Map<int, ProviderSubscription<DocumentModel>> _keepAlive = {};

  @override
  List<int> build() => const [];

  /// Opens the `.bnf` file at [path] and returns the new document's docID, or null if the file
  /// doesn't exist. Throws a [BnfFormatException] for invalid files.
  ///
  /// Only the first pages are read here; the rest is loaded on demand.
  Future<int?> open(String path) async {
    if (!await File(path).exists()) return null;
    print('open_documents: open: $path');

    final store = await DocumentStore.open(path);
    final metadata = store.metadata;

    final defaultPageJson = metadata['defaultPage'] as Map<String, dynamic>?;
    final defaultPage = defaultPageJson != null
        ? await PageModel.fromJson(defaultPageJson)
        : PageModel(pageWidth: 297, pageHeight: 210, pageColor: Colors.white70);

    var pageHeights = ((metadata['pageHeights'] as List?) ?? [0.0]).map((e) => (e as num).toDouble()).toList();
    var pageList = ((metadata['pageList'] as List?) ?? []).map((e) => (e as num).toInt()).toList();

    // Drop pages that are listed but not stored (e.g. added, then the app died before saving).
    final missing = pageList.where((id) => !store.hasPage(id)).toSet();
    if (missing.isNotEmpty) {
      print('open_documents: open: missing pages $missing');
      if (pageHeights.length == pageList.length) {
        pageHeights = [
          for (var i = 0; i < pageList.length; i++)
            if (!missing.contains(pageList[i])) pageHeights[i],
        ];
      }
      pageList = pageList.where((id) => !missing.contains(id)).toList();
    }

    final pages = await store.loadPages(pageList.take(DocumentNotifier.lazyLoadRange + 1).toList());

    final document = DocumentModel(
      pathToFile: path,
      pages: pages,
      docBackgroundColor: Colors.purpleAccent,
      defaultPage: defaultPage,
      author: metadata['author'] as String? ?? '?',
      title: metadata['title'] as String? ?? '?',
      created: metadata['created'] != null ? DateTime.parse(metadata['created'] as String) : DateTime.now(),
      pageHeights: pageHeights,
      pageList: pageList,
    );

    final docID = document.docID;
    _opened[docID] = (document: document, store: store);
    _keepAlive[docID] = ref.listen(documentProvider(docID), (_, _) {});
    state = [...state, docID];
    print('open_documents: open: docID=$docID, ${pageList.length} pages, loaded ${pages.length}');
    return docID;
  }

  /// Hands the document read by [open] to its provider (called once, from its build).
  ({DocumentModel document, DocumentStore store}) takeOpened(int docID) {
    final opened = _opened.remove(docID);
    if (opened == null) throw StateError('Document $docID was not opened (or is closed)');
    return opened;
  }

  /// Saves and closes document [docID]. Its provider is disposed once no widget watches it.
  Future<void> close(int docID) async {
    if (!state.contains(docID)) return;
    try {
      await ref.read(documentProvider(docID).notifier).closeStore();
    } finally {
      _keepAlive.remove(docID)?.close();
      ref.read(pageTilesProvider.notifier).removeDocument(docID);
      state = state.where((id) => id != docID).toList();
      if (ref.read(activeDocumentProvider) == docID) ref.read(activeDocumentProvider.notifier).set(null);
    }
  }
}

final openDocumentsProvider = NotifierProvider<OpenDocumentsNotifier, List<int>>(OpenDocumentsNotifier.new);

/// The document shown in the editor (null in the file manager).
class ActiveDocumentNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? docID) => state = docID;
}

final activeDocumentProvider = NotifierProvider<ActiveDocumentNotifier, int?>(ActiveDocumentNotifier.new);
