import 'dart:async';

import 'package:betternotes/core/bnf/bnf_repository.dart';

import '../models/page/page_model.dart';
import 'document_file.dart';

/// The file behind one open document: page loading, saving and closing.
///
/// Saves run one after another in call order. Each save asks for the document metadata when it
/// actually writes (not when it was requested), so a save queued behind another one never writes
/// an outdated page list.
class DocumentStore {
  DocumentStore._(this.repository);

  final BnfRepository repository;
  Future<void> _saveChain = Future.value();
  bool _closed = false;

  /// [close] compacts when at least this share of the file can be freed.
  static const double closeCompactRatio = 0.1;

  /// Opens the `.bnf` file at [path]. Throws a [BnfFormatException] for invalid files.
  static Future<DocumentStore> open(String path) async => DocumentStore._(await BnfRepository.open(path));

  String get path => repository.path;
  Map<String, dynamic> get metadata => repository.metadata;
  bool hasPage(int pageID) => repository.hasPage(pageID);
  bool get isClosed => _closed;

  /// Reads the pages with [pageIDs], in that order. Pages missing from the file are left out;
  /// returns [] once the store is closed.
  Future<List<PageModel>> loadPages(List<int> pageIDs) async {
    if (pageIDs.isEmpty || _closed) return [];
    try {
      final records = await repository.readPages(pageIDs);
      return await decodePages(repository, [
        for (final id in pageIDs)
          if (records[id] != null) records[id]!,
      ]);
    } on StateError {
      print('document_store: loadPages: $path was closed while loading');
      return [];
    }
  }

  /// Saves [pages] (unchanged ones are skipped) and the metadata returned by [metadata] at write
  /// time. [metadata] returns null if the document is gone; nothing is written then.
  /// Compacts the file when enough garbage has piled up (keeping deleted pages: the undo history
  /// may still need them).
  Future<void> save(List<PageModel> pages, Map<String, dynamic>? Function() metadata) {
    final save = _saveChain.then((_) async {
      if (_closed) {
        print('document_store: save: $path is closed, ${pages.length} page(s) not saved');
        return;
      }
      final encoded = await encodePages(pages);
      final currentMetadata = metadata();
      if (currentMetadata == null) return;
      final written = await repository.write(pages: encoded.pages, images: encoded.images, metadata: currentMetadata);
      if (written && repository.shouldCompact) {
        print('document_store: compacting $path (${repository.garbageBytes} of ${repository.fileLength} bytes garbage)');
        await repository.compact();
      }
    });
    _saveChain = save.then((_) {}, onError: (_) {});
    return save;
  }

  /// Waits for running saves, compacts the file if that frees enough space and closes it.
  /// Pages not in [keepPages] are dropped from the file (the undo history that could bring them
  /// back ends with the document).
  Future<void> close(Set<int> keepPages) async {
    if (_closed) return;
    await _saveChain;
    _closed = true;
    try {
      final reclaimable = await repository.reclaimableBytes(keepPages);
      if (reclaimable > 0 && reclaimable >= repository.fileLength * closeCompactRatio) {
        await repository.compact(keepPages: keepPages);
      }
    } finally {
      await repository.close();
    }
  }
}
