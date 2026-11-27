import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reading and writing of `.bnf` files (format v2, see `docs/bnf-format.md`).
///
/// This file is pure Dart (no Flutter imports) so it can be tested without a device.
/// It only deals with bytes: encoding pages and images is the job of the models.
///
/// One [BnfRepository] belongs to one open file. All operations on it run one after another
/// (an internal lock), so a save can't interleave with a compaction or another save.

/// Type of an index entry.
enum BnfEntryType {
  page(1),
  pdf(2),
  image(3);

  const BnfEntryType(this.code);

  /// Value stored in the file.
  final int code;

  static BnfEntryType fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    throw BnfFormatException('Unknown entry type: $code');
  }
}

/// Thrown when a file is not a `.bnf` file, has an unsupported version, or is corrupted.
class BnfFormatException implements Exception {
  BnfFormatException(this.message);

  final String message;

  @override
  String toString() => 'BnfFormatException: $message';
}

/// A page as stored in the file: the encoded page plus the IDs of the image blocks it uses.
///
/// [imageIDs] lets the repository find unused images during compaction without decoding pages.
class BnfPageRecord {
  BnfPageRecord({required this.id, required this.data, this.imageIDs = const []});

  final int id;
  final Uint8List data;
  final List<int> imageIDs;
}

/// Key of an index entry.
typedef BnfKey = ({BnfEntryType type, int id});

/// Position of a block in the file. [offset] points at the block's length field,
/// [length] is the length of the block data (without the 8-byte length field).
typedef BnfBlock = ({int offset, int length});

class BnfRepository {
  BnfRepository._(this.path, this._metadata, this._metadataLength,
      this._index, this._fileLength);

  static const int version = 2;
  static const List<int> magic = [0x42, 0x4E, 0x46, 0x00]; // "BNF\0"
  static const int headerLength = 16;
  static const int rootLength = 32;
  static const int indexEntryLength = 25;

  /// Automatic compaction ([shouldCompact]) needs at least this share of garbage ...
  static const double compactRatio = 0.5;

  /// ... and at least this many garbage bytes, so small files aren't rewritten all the time.
  static const int compactMinBytes = 256 * 1024;

  /// Chunk size for copying blocks during compaction.
  static const int _copyChunk = 1024 * 1024;

  final String path;

  Map<String, dynamic> _metadata;
  int _metadataLength;
  Map<BnfKey, BnfBlock> _index;
  int _fileLength;
  bool _closed = false;

  Future<void> _tail = Future.value();

  // ============================================================
  // Opening and creating
  // ============================================================

  /// Creates a new file at [path] and opens it.
  ///
  /// Throws a [FileSystemException] if the file already exists and [overwrite] is false.
  static Future<BnfRepository> create(
    String path, {
    required Map<String, dynamic> metadata,
    List<BnfPageRecord> pages = const [],
    Map<int, Uint8List> images = const {},
    bool overwrite = false,
  }) async {
    final file = File(path);
    if (!overwrite && await file.exists()) {
      throw FileSystemException('File already exists', path);
    }

    final builder = BytesBuilder(copy: false);
    builder.add(_header(0));
    final index = <BnfKey, BnfBlock>{};
    for (final entry in images.entries) {
      index[(type: BnfEntryType.image, id: entry.key)] = _addBlock(builder, entry.value);
    }
    for (final page in pages) {
      index[(type: BnfEntryType.page, id: page.id)] = _addBlock(builder, _encodePage(page));
    }
    final rootOffset = _addTail(builder, _withModified(metadata), index);
    final bytes = builder.takeBytes();
    ByteData.sublistView(bytes).setUint64(8, rootOffset, Endian.little);

    // Write next to the target and rename, so a crash never leaves a half-written file at [path].
    final temp = File('$path.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(path);

    return open(path);
  }

  /// Opens an existing file. Reads header, root, metadata and index; pages are read on demand.
  static Future<BnfRepository> open(String path) async {
    final raf = await File(path).open();
    try {
      final fileLength = await raf.length();
      if (fileLength < headerLength) {
        throw BnfFormatException('File too small ($fileLength bytes)');
      }

      final header = ByteData.sublistView(await _readExact(raf, 0, headerLength));
      for (var i = 0; i < magic.length; i++) {
        if (header.getUint8(i) != magic[i]) {
          throw BnfFormatException('Not a .bnf file (wrong magic)');
        }
      }
      final fileVersion = header.getUint32(4, Endian.little);
      if (fileVersion != version) {
        throw BnfFormatException('Unsupported version: $fileVersion');
      }
      final rootOffset = header.getUint64(8, Endian.little);
      if (rootOffset < headerLength || rootOffset + rootLength > fileLength) {
        throw BnfFormatException('Invalid root offset $rootOffset (file length $fileLength)');
      }

      final root = ByteData.sublistView(await _readExact(raf, rootOffset, rootLength));
      final metadataOffset = root.getUint64(0, Endian.little);
      final metadataLength = root.getUint64(8, Endian.little);
      final indexOffset = root.getUint64(16, Endian.little);
      final indexLength = root.getUint64(24, Endian.little);

      final metadataBytes = await _readBlock(raf, (offset: metadataOffset, length: metadataLength), fileLength);
      final Map<String, dynamic> metadata;
      try {
        metadata = jsonDecode(utf8.decode(metadataBytes)) as Map<String, dynamic>;
      } on FormatException catch (e) {
        throw BnfFormatException('Invalid metadata: ${e.message}');
      }

      final indexBytes = await _readBlock(raf, (offset: indexOffset, length: indexLength), fileLength);
      final index = _decodeIndex(indexBytes, fileLength);

      return BnfRepository._(path, metadata, metadataLength, index, fileLength);
    } finally {
      await raf.close();
    }
  }

  // ============================================================
  // State
  // ============================================================

  /// Document metadata (title, page list, ...). Includes `modified`, set on every write.
  Map<String, dynamic> get metadata => _metadata;

  /// IDs of all pages in the index (may include pages that are no longer in the page list,
  /// until the next compaction with `keepPages`).
  Set<int> get pageIDs => {
        for (final key in _index.keys)
          if (key.type == BnfEntryType.page) key.id
      };

  Set<int> get imageIDs => {
        for (final key in _index.keys)
          if (key.type == BnfEntryType.image) key.id
      };

  bool hasPage(int id) => _index.containsKey((type: BnfEntryType.page, id: id));

  bool hasImage(int id) => _index.containsKey((type: BnfEntryType.image, id: id));

  int get fileLength => _fileLength;

  /// Bytes that the current root references (header, blocks, metadata, index, root).
  int get liveBytes {
    var total = headerLength + 8 + _metadataLength + 8 + 4 + _index.length * indexEntryLength + rootLength;
    for (final block in _index.values) {
      total += 8 + block.length;
    }
    return total;
  }

  /// Bytes left over from earlier saves (old page versions, old indexes, ...).
  int get garbageBytes => _fileLength - liveBytes;

  /// Whether enough garbage has piled up to make a compaction worth it.
  bool get shouldCompact =>
      garbageBytes >= compactMinBytes && garbageBytes >= _fileLength * compactRatio;

  /// Bytes a `compact(keepPages: keepPages)` would free: garbage, pages not in [keepPages], and
  /// images only those pages use. Reads the image references at the start of each page block.
  Future<int> reclaimableBytes(Set<int> keepPages) => _locked(() async {
        var bytes = garbageBytes;
        final usedImages = <int>{};
        final raf = await File(path).open();
        try {
          for (final entry in _index.entries) {
            if (entry.key.type != BnfEntryType.page) continue;
            if (!keepPages.contains(entry.key.id)) {
              bytes += 8 + entry.value.length + indexEntryLength;
              continue;
            }
            final block = entry.value;
            if (block.length < 4) throw BnfFormatException('Page ${entry.key.id} too small');
            final count = ByteData.sublistView(await _readExact(raf, block.offset + 8, 4)).getUint32(0, Endian.little);
            if (4 + count * 8 > block.length) throw BnfFormatException('Page ${entry.key.id}: invalid image count');
            final ids = ByteData.sublistView(await _readExact(raf, block.offset + 12, count * 8));
            for (var i = 0; i < count; i++) {
              usedImages.add(ids.getUint64(i * 8, Endian.little));
            }
          }
        } finally {
          await raf.close();
        }
        for (final entry in _index.entries) {
          if (entry.key.type == BnfEntryType.image && !usedImages.contains(entry.key.id)) {
            bytes += 8 + entry.value.length + indexEntryLength;
          }
        }
        return bytes;
      });

  // ============================================================
  // Reading
  // ============================================================

  /// Reads the pages with [ids]. Pages not in the file are left out of the result.
  /// Only the requested blocks are read, not the whole file.
  Future<Map<int, BnfPageRecord>> readPages(Iterable<int> ids) => _locked(() async {
        final result = <int, BnfPageRecord>{};
        final blocks = <int, BnfBlock>{};
        for (final id in ids) {
          final block = _index[(type: BnfEntryType.page, id: id)];
          if (block != null) blocks[id] = block;
        }
        if (blocks.isEmpty) return result;

        final raf = await File(path).open();
        try {
          for (final entry in blocks.entries) {
            final bytes = await _readBlock(raf, entry.value, _fileLength);
            result[entry.key] = _decodePage(entry.key, bytes);
          }
        } finally {
          await raf.close();
        }
        return result;
      });

  Future<BnfPageRecord?> readPage(int id) async => (await readPages([id]))[id];

  /// Reads the image block [id], or returns null if it doesn't exist.
  Future<Uint8List?> readImage(int id) => _locked(() async {
        final block = _index[(type: BnfEntryType.image, id: id)];
        if (block == null) return null;
        final raf = await File(path).open();
        try {
          return await _readBlock(raf, block, _fileLength);
        } finally {
          await raf.close();
        }
      });

  // ============================================================
  // Writing
  // ============================================================

  /// Appends changed [pages], new [images] and [metadata], then switches the root to them.
  ///
  /// Pages whose bytes equal the stored version are skipped; images that already exist are
  /// skipped (image IDs are content hashes). Nothing is written if neither pages, images nor
  /// metadata changed. Returns whether anything was written.
  ///
  /// Crash safety: everything new is appended and flushed before the root pointer in the header
  /// is updated (and flushed). A crash before that leaves the old root, so the file still opens
  /// with its previous content; the appended bytes are garbage.
  Future<bool> write({
    List<BnfPageRecord> pages = const [],
    Map<int, Uint8List> images = const {},
    required Map<String, dynamic> metadata,
  }) => _locked(() async {
        final raf = await File(path).open(mode: FileMode.append);
        try {
          final newIndex = Map<BnfKey, BnfBlock>.of(_index);
          final builder = BytesBuilder(copy: false);
          var offset = _fileLength;
          var changed = false;

          for (final entry in images.entries) {
            final key = (type: BnfEntryType.image, id: entry.key);
            if (newIndex.containsKey(key)) continue;
            final block = _addBlock(builder, entry.value, at: offset);
            newIndex[key] = block;
            offset += 8 + block.length;
            changed = true;
          }

          for (final page in pages) {
            final key = (type: BnfEntryType.page, id: page.id);
            final data = _encodePage(page);
            final old = newIndex[key];
            if (old != null && old.length == data.length &&
                _bytesEqual(await _readBlock(raf, old, _fileLength), data)) {
              continue;
            }
            final block = _addBlock(builder, data, at: offset);
            newIndex[key] = block;
            offset += 8 + block.length;
            changed = true;
          }

          if (!changed && _sameMetadata(metadata)) return false;

          final storedMetadata = _withModified(metadata);
          final rootOffset = _addTail(builder, storedMetadata, newIndex, at: offset);
          final bytes = builder.takeBytes();

          await raf.setPosition(_fileLength);
          await raf.writeFrom(bytes);
          await raf.flush();

          await raf.setPosition(8);
          await raf.writeFrom(_uint64(rootOffset));
          await raf.flush();

          _fileLength += bytes.length;
          _index = newIndex;
          _metadata = storedMetadata;
          _metadataLength = utf8.encode(jsonEncode(storedMetadata)).length;
          return true;
        } finally {
          await raf.close();
        }
      });

  // ============================================================
  // Compaction
  // ============================================================

  /// Rewrites the file without garbage.
  ///
  /// If [keepPages] is given, pages not in it are dropped, and so are images no remaining page
  /// uses. Otherwise every indexed page and image is kept (safe while undo history may still
  /// need pages that were deleted from the document).
  ///
  /// The new file is written next to the old one, flushed, and renamed over it, so a crash
  /// leaves either the old or the new file. Blocks are copied in chunks.
  /// Block offsets change; anything that cached them must reread them from this repository.
  Future<void> compact({Set<int>? keepPages}) => _locked(() async {
        final oldLength = _fileLength;
        final temp = File('$path.compact.tmp');
        final source = await File(path).open();
        final target = await temp.open(mode: FileMode.write);
        final newIndex = <BnfKey, BnfBlock>{};
        var filesOpen = true;
        Future<void> closeFiles() async {
          if (!filesOpen) return;
          filesOpen = false;
          await target.close();
          await source.close();
        }

        try {
          // Decide which blocks survive.
          final keep = <BnfKey>[];
          if (keepPages == null) {
            keep.addAll(_index.keys);
          } else {
            final usedImages = <int>{};
            for (final key in _index.keys) {
              if (key.type == BnfEntryType.page && keepPages.contains(key.id)) {
                keep.add(key);
                final page = _decodePage(key.id, await _readBlock(source, _index[key]!, _fileLength));
                usedImages.addAll(page.imageIDs);
              }
            }
            for (final key in _index.keys) {
              if (key.type == BnfEntryType.pdf ||
                  (key.type == BnfEntryType.image && usedImages.contains(key.id))) {
                keep.add(key);
              }
            }
          }

          await target.writeFrom(_header(0));
          var offset = headerLength;
          for (final key in keep) {
            final block = _index[key]!;
            if (block.offset + 8 + block.length > _fileLength) {
              throw BnfFormatException('Block $key lies outside the file');
            }
            await target.writeFrom(_uint64(block.length));
            var copied = 0;
            while (copied < block.length) {
              final n = (block.length - copied).clamp(0, _copyChunk);
              await target.writeFrom(await _readExact(source, block.offset + 8 + copied, n));
              copied += n;
            }
            newIndex[key] = (offset: offset, length: block.length);
            offset += 8 + block.length;
          }

          final builder = BytesBuilder(copy: false);
          final rootOffset = _addTail(builder, _metadata, newIndex, at: offset);
          final tail = builder.takeBytes();
          await target.writeFrom(tail);
          await target.flush();
          await target.setPosition(8);
          await target.writeFrom(_uint64(rootOffset));
          await target.flush();

          await closeFiles();
          await temp.rename(path);

          _fileLength = offset + tail.length;
          _index = newIndex;
          print('bnf_repository: compact: $oldLength -> $_fileLength bytes');
        } catch (_) {
          await closeFiles();
          if (await temp.exists()) await temp.delete();
          rethrow;
        }
      });

  /// Waits for running operations and closes the repository. Later calls throw a [StateError].
  Future<void> close() async {
    await _locked(() async {});
    _closed = true;
  }

  // ============================================================
  // Helpers
  // ============================================================

  /// Runs [action] after all earlier operations finished.
  Future<T> _locked<T>(Future<T> Function() action) {
    if (_closed) throw StateError('BnfRepository for $path is closed');
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  bool _sameMetadata(Map<String, dynamic> metadata) {
    final current = Map<String, dynamic>.of(_metadata)..remove('modified');
    final given = Map<String, dynamic>.of(metadata)..remove('modified');
    return jsonEncode(current) == jsonEncode(given);
  }

  static Map<String, dynamic> _withModified(Map<String, dynamic> metadata) =>
      {...metadata, 'modified': DateTime.now().toIso8601String()};

  static Uint8List _header(int rootOffset) {
    final data = ByteData(headerLength);
    for (var i = 0; i < magic.length; i++) {
      data.setUint8(i, magic[i]);
    }
    data.setUint32(4, version, Endian.little);
    data.setUint64(8, rootOffset, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _uint64(int value) =>
      (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List();

  /// Adds `[u64 length | data]` to [builder]; [at] is the file offset where it will end up.
  static BnfBlock _addBlock(BytesBuilder builder, Uint8List data, {int? at}) {
    final offset = at ?? builder.length;
    builder.add(_uint64(data.length));
    builder.add(data);
    return (offset: offset, length: data.length);
  }

  /// Adds metadata block, index block and root to [builder]. Returns the root's file offset.
  static int _addTail(BytesBuilder builder, Map<String, dynamic> metadata,
      Map<BnfKey, BnfBlock> index, {int? at}) {
    var offset = at ?? builder.length;
    final metadataBlock = _addBlock(builder, utf8.encode(jsonEncode(metadata)), at: offset);
    offset += 8 + metadataBlock.length;
    final indexBlock = _addBlock(builder, _encodeIndex(index), at: offset);
    offset += 8 + indexBlock.length;

    final root = ByteData(rootLength)
      ..setUint64(0, metadataBlock.offset, Endian.little)
      ..setUint64(8, metadataBlock.length, Endian.little)
      ..setUint64(16, indexBlock.offset, Endian.little)
      ..setUint64(24, indexBlock.length, Endian.little);
    builder.add(root.buffer.asUint8List());
    return offset;
  }

  static Uint8List _encodeIndex(Map<BnfKey, BnfBlock> index) {
    final data = ByteData(4 + index.length * indexEntryLength);
    data.setUint32(0, index.length, Endian.little);
    var position = 4;
    for (final entry in index.entries) {
      data.setUint8(position, entry.key.type.code);
      data.setUint64(position + 1, entry.key.id, Endian.little);
      data.setUint64(position + 9, entry.value.offset, Endian.little);
      data.setUint64(position + 17, entry.value.length, Endian.little);
      position += indexEntryLength;
    }
    return data.buffer.asUint8List();
  }

  static Map<BnfKey, BnfBlock> _decodeIndex(Uint8List bytes, int fileLength) {
    if (bytes.length < 4) throw BnfFormatException('Index too small');
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(0, Endian.little);
    if (bytes.length != 4 + count * indexEntryLength) {
      throw BnfFormatException('Index length ${bytes.length} does not match $count entries');
    }
    final index = <BnfKey, BnfBlock>{};
    var position = 4;
    for (var i = 0; i < count; i++) {
      final type = BnfEntryType.fromCode(data.getUint8(position));
      final id = data.getUint64(position + 1, Endian.little);
      final offset = data.getUint64(position + 9, Endian.little);
      final length = data.getUint64(position + 17, Endian.little);
      if (offset < headerLength || offset + 8 + length > fileLength) {
        throw BnfFormatException('Index entry ($type, $id) points outside the file');
      }
      index[(type: type, id: id)] = (offset: offset, length: length);
      position += indexEntryLength;
    }
    return index;
  }

  /// Page block: `u32 imageCount | u64 imageIDs... | page data`.
  static Uint8List _encodePage(BnfPageRecord page) {
    final prefix = ByteData(4 + page.imageIDs.length * 8);
    prefix.setUint32(0, page.imageIDs.length, Endian.little);
    for (var i = 0; i < page.imageIDs.length; i++) {
      prefix.setUint64(4 + i * 8, page.imageIDs[i], Endian.little);
    }
    return (BytesBuilder(copy: false)
          ..add(prefix.buffer.asUint8List())
          ..add(page.data))
        .takeBytes();
  }

  static BnfPageRecord _decodePage(int id, Uint8List bytes) {
    if (bytes.length < 4) throw BnfFormatException('Page $id too small');
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(0, Endian.little);
    final dataStart = 4 + count * 8;
    if (dataStart > bytes.length) throw BnfFormatException('Page $id: invalid image count');
    final imageIDs = [for (var i = 0; i < count; i++) data.getUint64(4 + i * 8, Endian.little)];
    return BnfPageRecord(id: id, data: Uint8List.sublistView(bytes, dataStart), imageIDs: imageIDs);
  }

  /// Reads `[u64 length | data]` at [block] and checks the stored length.
  static Future<Uint8List> _readBlock(RandomAccessFile raf, BnfBlock block, int fileLength) async {
    if (block.offset < headerLength || block.offset + 8 + block.length > fileLength) {
      throw BnfFormatException('Block at ${block.offset} (length ${block.length}) lies outside the file');
    }
    final stored = ByteData.sublistView(await _readExact(raf, block.offset, 8)).getUint64(0, Endian.little);
    if (stored != block.length) {
      throw BnfFormatException('Block at ${block.offset}: stored length $stored, expected ${block.length}');
    }
    return _readExact(raf, block.offset + 8, block.length);
  }

  static Future<Uint8List> _readExact(RandomAccessFile raf, int offset, int length) async {
    await raf.setPosition(offset);
    final bytes = await raf.read(length);
    if (bytes.length != length) {
      throw BnfFormatException('Unexpected end of file at ${offset + bytes.length}');
    }
    return bytes;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
