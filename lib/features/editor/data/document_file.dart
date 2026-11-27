import 'dart:typed_data';

import 'package:betternotes/core/bnf/bnf_repository.dart';

import '../models/page/document_model.dart';
import '../models/page/page_model.dart';

/// Glue between the editor models and [BnfRepository]: turns pages into page records and
/// image blocks and back.

/// Encoded pages ready for [BnfRepository.write].
typedef EncodedPages = ({List<BnfPageRecord> pages, Map<int, Uint8List> images});

/// Encodes [pages], skipping placeholder pages (`isTemp`).
Future<EncodedPages> encodePages(Iterable<PageModel> pages) async {
  final records = <BnfPageRecord>[];
  final images = <int, Uint8List>{};
  for (final page in pages) {
    if (page.isTemp) continue;
    final encoded = await page.encode();
    records.add(BnfPageRecord(id: page.pageID, data: encoded.bytes, imageIDs: encoded.images.keys.toList()));
    images.addAll(encoded.images);
  }
  return (pages: records, images: images);
}

/// Decodes page records read from [repository].
Future<List<PageModel>> decodePages(BnfRepository repository, Iterable<BnfPageRecord> records) async {
  return [
    for (final record in records) await PageModel.decode(record.data, repository.readImage),
  ];
}

/// Creates a new `.bnf` file at [path] holding [doc] and its loaded pages, and returns it opened.
Future<BnfRepository> createDocumentFile(String path, DocumentModel doc, {bool overwrite = false}) async {
  final encoded = await encodePages(doc.pages);
  return BnfRepository.create(
    path,
    metadata: doc.toMetadata(),
    pages: encoded.pages,
    images: encoded.images,
    overwrite: overwrite,
  );
}
