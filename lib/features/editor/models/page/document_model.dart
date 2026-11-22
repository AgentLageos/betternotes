import 'dart:convert';
import 'package:flutter/material.dart';

import 'page_model.dart';
import '../commands/command.dart';
import 'package:betternotes/core/utils/id_generator.dart';

import 'dart:typed_data';

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






  Map<String, dynamic> generateMetaDataJson(List<int> firstPageIDs, List<double> firstPageHeights) {
    return {
      'title': title,
      'author': author,
      'created' : DateTime.now().toIso8601String(),
      'modified': DateTime.now().toIso8601String(),
      'defaultPage' : defaultPage.toJson(),
      //'totalPages' : totalPages,
      'pageHeights' : firstPageHeights,
      'pageList': firstPageIDs,

    };
  }

  Map<String, dynamic> updateMetaDataJson() {
    return {
      'title': title,
      'author': author,
      'created' : created.toIso8601String(),
      'modified': DateTime.now().toIso8601String(),
      'defaultPage' : defaultPage.toJson(),
      //'totalPages' : totalPages,
      'pageHeights' : pageHeights,
      'pageList': pageList,
    };
  }




  Future<Uint8List> toBytes() async {
    final builder = BytesBuilder();

    // ============================================================
    // HEADER
    // ============================================================
    //
    // 0..7   = Magic / Version
    // 8..15  = rootOffset
    //
    // rootOffset is set at the end.
    // ============================================================

    final magic = ByteData(8)
      ..setUint64(
        0,
        1, // Version 1
        Endian.little,
      );

    builder.add(
      magic.buffer.asUint8List(),
    );

    // placeholder for rootOffset
    builder.add(
      Uint8List(8),
    );

    // ============================================================
    // METADATA
    // ============================================================

    final metadata = {
      'title': title,
      'author': author,
      'created': created.toIso8601String(),
      'modified': DateTime.now().toIso8601String(),
      'defaultPage': defaultPage.toJson(),
      'pageHeights': pageHeights,
      'pageList': pageList,
    };

    final metadataBytes = utf8.encode(
      jsonEncode(metadata),
    );

    // metadata starts here
    final metadataOffset = 16;

    // metadata length
    final metadataLength = ByteData(8)
      ..setUint64(
        0,
        metadataBytes.length,
        Endian.little,
      );

    builder.add(
      metadataLength.buffer.asUint8List(),
    );

    builder.add(metadataBytes);

    // ============================================================
    // PAGES
    // ============================================================

    final pageOffsets = <int, int>{};
    final pageLengths = <int, int>{};

    var currentOffset =
        metadataOffset +
            8 +
            metadataBytes.length;

    for (final page in pages) {
      final pageBytes = await page.toBytes();

      // The offset points to the 8-byte length field.
      pageOffsets[page.pageID] = currentOffset;

      pageLengths[page.pageID] = pageBytes.length;

      // ----------------------------------------------------------
      // Page Length
      // ----------------------------------------------------------

      final pageLength = ByteData(8)
        ..setUint64(
          0,
          pageBytes.length,
          Endian.little,
        );

      builder.add(
        pageLength.buffer.asUint8List(),
      );

      // ----------------------------------------------------------
      // Page Data
      // ----------------------------------------------------------

      builder.add(pageBytes);

      currentOffset += 8 + pageBytes.length;
    }

    // ============================================================
    // INDEX
    // ============================================================

    final indexOffset = currentOffset;

    final indexCount = ByteData(4)
      ..setUint32(
        0,
        pages.length,
        Endian.little,
      );

    builder.add(
      indexCount.buffer.asUint8List(),
    );

    currentOffset += 4;

    for (final page in pages) {
      final entry = ByteData(24)
        ..setUint64(
          0,
          page.pageID,
          Endian.little,
        )
        ..setUint64(
          8,
          pageOffsets[page.pageID]!,
          Endian.little,
        )
        ..setUint64(
          16,
          pageLengths[page.pageID]!,
          Endian.little,
        );

      builder.add(
        entry.buffer.asUint8List(),
      );

      currentOffset += 24;
    }

    // ============================================================
    // ROOT
    // ============================================================
    //
    // The root describes the current version:
    //
    // metadataOffset
    // metadataLength
    // indexOffset
    // indexLength
    //
    // ============================================================

    final rootOffset = currentOffset;

    final indexLength =
        currentOffset - indexOffset;

    final root = ByteData(32)
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

    builder.add(
      root.buffer.asUint8List(),
    );

    // ============================================================
    // ROOT OFFSET IN DEN HEADER SCHREIBEN
    // ============================================================

    final result = builder.takeBytes();

    final resultData = ByteData.sublistView(result);

    resultData.setUint64(
      8,
      rootOffset,
      Endian.little,
    );

    return result;
  }


  static Future<DocumentModel> fromBytes(Uint8List bytes) async {
    final data = ByteData.sublistView(bytes);

    // ============================================================
    // HEADER
    //
    // 0..7   = Version
    // 8..15  = Root Offset
    // ============================================================

    if (bytes.length < 16) {
      throw Exception('Invalid file: Header is too small');
    }

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

    if (rootOffset < 16 ||
        rootOffset + 32 > bytes.length) {
      throw Exception(
        'Invalid root offset: $rootOffset '
            '(file length: ${bytes.length})',
      );
    }

    // ============================================================
    // ROOT
    //
    // 0..7   = metadataOffset
    // 8..15  = metadataLength
    // 16..23 = indexOffset
    // 24..31 = indexLength
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

    final indexOffset = root.getUint64(
      16,
      Endian.little,
    );

    final indexLength = root.getUint64(
      24,
      Endian.little,
    );

    // ============================================================
    // METADATA
    //
    // metadataOffset points to:
    //
    // [8 Bytes metadataLength]
    // [metadata]
    // ============================================================

    if (metadataOffset + 8 + metadataLength >
        bytes.length) {
      throw Exception(
        'Invalid metadata range: '
            'offset=$metadataOffset, '
            'length=$metadataLength',
      );
    }

    final storedMetadataLength = data.getUint64(
      metadataOffset,
      Endian.little,
    );

    if (storedMetadataLength != metadataLength) {
      throw Exception(
        'Metadata length mismatch: '
            'root=$metadataLength, '
            'stored=$storedMetadataLength',
      );
    }

    final metadataStart = metadataOffset + 8;

    final metadataBytes = bytes.sublist(
      metadataStart,
      metadataStart + metadataLength,
    );

    final metadata = jsonDecode(
      utf8.decode(metadataBytes),
    ) as Map<String, dynamic>;

    // ============================================================
    // METADATA AUSLESEN
    // ============================================================

    final title = metadata['title'] as String;

    final author = metadata['author'] as String;

    final created = DateTime.parse(
      metadata['created'] as String,
    );

    final pageHeights = (metadata['pageHeights'] as List)
        .map(
          (e) => (e as num).toDouble(),
    )
        .toList();

    final pageList = (metadata['pageList'] as List)
        .map(
          (e) => (e as num).toInt(),
    )
        .toList();

    final defaultPageJson =
    metadata['defaultPage'] as Map<String, dynamic>;

    final defaultPage = await PageModel.fromJson(
      defaultPageJson,
    );

    // ============================================================
    // INDEX
    //
    // indexOffset points to:
    //
    // [4 Bytes indexCount]
    // [24 Bytes IndexEntry]
    // [24 Bytes IndexEntry]
    // ...
    //
    // IndexEntry:
    //   0..7   pageID
    //   8..15  pageOffset
    //   16..23 pageLength
    // ============================================================

    if (indexOffset + indexLength > bytes.length) {
      throw Exception(
        'Invalid index range: '
            'offset=$indexOffset, '
            'length=$indexLength',
      );
    }

    if (indexLength < 4) {
      throw Exception(
        'Invalid index length: $indexLength',
      );
    }

    final indexCount = data.getUint32(
      indexOffset,
      Endian.little,
    );

    final expectedIndexLength =
        4 + indexCount * 24;

    if (indexLength != expectedIndexLength) {
      throw Exception(
        'Invalid index length. '
            'Expected=$expectedIndexLength, '
            'actual=$indexLength',
      );
    }

    final index =
    <int, ({int offset, int length})>{};

    var indexEntryOffset = indexOffset + 4;

    for (int i = 0; i < indexCount; i++) {
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

      index[pageID] = (
      offset: pageOffset,
      length: pageLength,
      );

      indexEntryOffset += 24;
    }

    // ============================================================
    // PAGES
    //
    // The order comes from pageList.
    //
    // pageList
    //    ↓
    // pageID
    //    ↓
    // index[pageID]
    //    ↓
    // pageOffset + pageLength
    //    ↓
    // PageModel.fromBytes()
    // ============================================================

    final pages = <PageModel>[];

    for (final pageID in pageList) {
      final indexEntry = index[pageID];

      if (indexEntry == null) {
        throw Exception(
          'Page $pageID is in pageList '
              'but missing in index.',
        );
      }

      final pageOffset = indexEntry.offset;
      final pageLength = indexEntry.length;

      // pageOffset points to:
      //
      // [8 Bytes pageLength]
      // [pageBytes]
      //

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
          'Page length mismatch for pageID=$pageID: '
              'index=$pageLength, '
              'stored=$storedPageLength',
        );
      }

      final pageDataStart = pageOffset + 8;

      final pageBytes = bytes.sublist(
        pageDataStart,
        pageDataStart + pageLength,
      );

      final page = await PageModel.fromBytes(
        pageBytes,
      );

      pages.add(page);
    }

    // ============================================================
    // DOCUMENT
    // ============================================================

    return DocumentModel(
      pages: pages,
      defaultPage: defaultPage,
      created: created,
      author: author,
      title: title,
      pageHeights: pageHeights,
      pageList: pageList,
    );
  }




  Future<String> fromBytesToJson(Uint8List bytes) async {
    final data = ByteData.sublistView(bytes);

    // ============================================================
    // Hilfsfunktionen
    // ============================================================

    void checkRange(int offset, int length, String what) {
      if (offset < 0 || length < 0 || offset + length > bytes.length) {
        throw FormatException(
          '$what outside of the file: '
              'offset=$offset, length=$length, fileLength=${bytes.length}',
        );
      }
    }

    int getUint64(int offset) {
      checkRange(offset, 8, 'uint64');

      return data.getUint64(
        offset,
        Endian.little,
      );
    }

    int getUint32(int offset) {
      checkRange(offset, 4, 'uint32');

      return data.getUint32(
        offset,
        Endian.little,
      );
    }

    // ============================================================
    // HEADER
    // ============================================================

    if (bytes.length < 16) {
      throw FormatException(
        'File is too small for the header.',
      );
    }

    final version = getUint64(0);
    final rootOffset = getUint64(8);

    // ============================================================
    // ROOT
    //
    // Root:
    // 0..7   metadataOffset
    // 8..15  metadataLength
    // 16..23 indexOffset
    // 24..31 indexLength
    // ============================================================

    checkRange(
      rootOffset,
      32,
      'Root',
    );

    final rootData = ByteData.sublistView(
      bytes,
      rootOffset,
      rootOffset + 32,
    );

    final metadataOffset = rootData.getUint64(
      0,
      Endian.little,
    );

    final metadataLength = rootData.getUint64(
      8,
      Endian.little,
    );

    final indexOffset = rootData.getUint64(
      16,
      Endian.little,
    );

    final indexLength = rootData.getUint64(
      24,
      Endian.little,
    );

    // ============================================================
    // METADATA
    //
    // At metadataOffset:
    //
    // 8 Bytes metadataLength
    // followed by JSON
    // ============================================================

    checkRange(
      metadataOffset,
      8 + metadataLength,
      'Metadata',
    );

    final storedMetadataLength = getUint64(
      metadataOffset,
    );

    if (storedMetadataLength != metadataLength) {
      // Debug information only.
      // Deliberately no error thrown here.
    }

    final metadataStart = metadataOffset + 8;

    final metadataBytes = bytes.sublist(
      metadataStart,
      metadataStart + metadataLength,
    );

    dynamic metadata;

    try {
      metadata = jsonDecode(
        utf8.decode(metadataBytes),
      );
    } catch (e) {
      metadata = {
        '_error': 'Metadata could not be read as JSON.',
        '_exception': e.toString(),
        '_rawUtf8': utf8.decode(
          metadataBytes,
          allowMalformed: true,
        ),
      };
    }

    // ============================================================
    // INDEX
    //
    // indexOffset:
    //
    // 4 Bytes indexCount
    //
    // Danach pro Eintrag:
    //
    // 8 Bytes pageID
    // 8 Bytes pageOffset
    // 8 Bytes pageLength
    // ============================================================

    checkRange(
      indexOffset,
      4,
      'Index',
    );

    final indexCount = getUint32(indexOffset);

    final indexEntries = <Map<String, dynamic>>[];

    var indexPosition = indexOffset + 4;

    for (var i = 0; i < indexCount; i++) {
      checkRange(
        indexPosition,
        24,
        'Index entry $i',
      );

      final entryData = ByteData.sublistView(
        bytes,
        indexPosition,
        indexPosition + 24,
      );

      final pageID = entryData.getUint64(
        0,
        Endian.little,
      );

      final pageOffset = entryData.getUint64(
        8,
        Endian.little,
      );

      final pageLength = entryData.getUint64(
        16,
        Endian.little,
      );

      indexEntries.add({
        'pageID': pageID,
        'offset': pageOffset,
        'length': pageLength,
      });

      indexPosition += 24;
    }

    // ============================================================
    // READ PAGES VIA THE INDEX
    // ============================================================

    final pages = <Map<String, dynamic>>[];

    for (final entry in indexEntries) {
      final pageID = entry['pageID'] as int;
      final pageOffset = entry['offset'] as int;
      final pageLength = entry['length'] as int;

      final pageInfo = <String, dynamic>{
        'pageID': pageID,
        'offset': pageOffset,
        'length': pageLength,
      };

      try {
        // pageOffset points to the 8-byte pageLength.
        checkRange(
          pageOffset,
          8 + pageLength,
          'Page $pageID',
        );

        final storedPageLength = getUint64(
          pageOffset,
        );

        pageInfo['storedLength'] = storedPageLength;

        pageInfo['lengthMatches'] =
            storedPageLength == pageLength;

        final pageDataStart = pageOffset + 8;

        final pageBytes = bytes.sublist(
          pageDataStart,
          pageDataStart + pageLength,
        );

        // --------------------------------------------------------
        // Optional versuchen, PageModel zu dekodieren.
        //
        // Falls dein PageModel.fromBytes anders aussieht,
        // diesen Teil entsprechend anpassen.
        // --------------------------------------------------------

        try {
          final page = await PageModel.fromBytes(
            pageBytes,
          );

          pageInfo['page'] = page.toJson();
        } catch (e) {
          pageInfo['pageDecodeError'] = e.toString();

          pageInfo['rawBytesLength'] = pageBytes.length;
        }
      } catch (e) {
        pageInfo['error'] = e.toString();
      }

      pages.add(pageInfo);
    }

    // ============================================================
    // PHYSISCHE DATEISTRUKTUR DEBUGGEN
    // ============================================================

    final result = <String, dynamic>{
      'file': {
        'length': bytes.length,
      },

      'header': {
        'version': version,
        'rootOffset': rootOffset,
      },

      'root': {
        'offset': rootOffset,
        'length': 32,
        'metadataOffset': metadataOffset,
        'metadataLength': metadataLength,
        'indexOffset': indexOffset,
        'indexLength': indexLength,
      },

      'metadata': metadata,

      'index': {
        'offset': indexOffset,
        'length': indexLength,
        'count': indexCount,
        'entries': indexEntries,
      },

      'pages': pages,

      // ----------------------------------------------------------
      // Sanity checks
      // ----------------------------------------------------------

      'debug': {
        'rootIsInsideFile':
        rootOffset + 32 <= bytes.length,

        'metadataIsInsideFile':
        metadataOffset + 8 + metadataLength <= bytes.length,

        'indexIsInsideFile':
        indexOffset + indexLength <= bytes.length,

        'indexLengthCalculated':
        4 + indexCount * 24,

        'indexLengthMatches':
        indexLength == 4 + indexCount * 24,

        'pageCountFromIndex':
        indexEntries.length,

        'pageCountFromMetadata':
        metadata is Map
            ? (metadata['pageList'] as List?)?.length
            : null,

        'pageIDsFromIndex':
        indexEntries
            .map((e) => e['pageID'])
            .toList(),

        'pageIDsFromMetadata':
        metadata is Map
            ? metadata['pageList']
            : null,
      },
    };

    return const JsonEncoder.withIndent(
      '  ',
    ).convert(result);
  }




}